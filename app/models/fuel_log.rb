class FuelLog < ApplicationRecord
  # An odometer gap wider than this is a data problem, not miles that were
  # actually driven: a cluster replacement, a unit swap, or a run of missed
  # fill-ups. Counting it would inflate miles and deflate cost per mile.
  MAX_INTERVAL_MILES = 2_000
  MAX_REASONABLE_MPG = 15.0

  belongs_to :user
  belongs_to :truck

  validates :fuel_date, presence: true
  validates :odometer, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :gallons, numericality: { greater_than: 0 }, allow_nil: true
  validates :price_per_gallon, :total_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :with_mpg_inputs, -> { where("odometer IS NOT NULL AND gallons IS NOT NULL AND gallons > 0") }

  def mpg_since_last_fill
    interval = interval_since_last_fill
    return nil unless interval && self.class.plausible_mpg?(interval)

    interval[:mpg]
  end

  def miles_since_last_fill
    interval_since_last_fill&.fetch(:miles)
  end

  class << self
    # --- Miles ---------------------------------------------------------------
    #
    # Miles come from odometer movement between consecutive fill-ups, which means
    # they no longer depend on gallons being recorded. A fill-up entered without
    # gallons still contributes its miles; it just cannot contribute an MPG
    # figure. This is the mileage that cost per mile and revenue per mile run on.

    def total_miles(scope = all)
      mileage_intervals(scope).sum { |interval| interval[:miles] }
    end

    def mileage_intervals(scope = all)
      odometer_intervals(scope).select { |interval| plausible_miles?(interval) }
    end

    def excluded_mileage_interval_count(scope = all)
      odometer_intervals(scope).count { |interval| !plausible_miles?(interval) }
    end

    # The distance a scope actually spans, per truck: earliest reference reading
    # (the truck's baseline when this is its first fill-up, otherwise its first
    # reading in scope) through to its last. This is the figure a driver gets by
    # subtracting one odometer from another by hand.
    def tracked_span(scope = all)
      logs = scope.where.not(odometer: nil)
        .reorder(:truck_id, :odometer, :fuel_date, :id)
        .to_a
      return 0 if logs.empty?

      trucks = Truck.where(id: logs.map(&:truck_id).uniq).index_by(&:id)

      logs.group_by(&:truck_id).sum do |truck_id, truck_logs|
        first_log = truck_logs.first
        starting_odometer = baseline_start_for(trucks[truck_id], first_log) || first_log.odometer

        [ truck_logs.last.odometer - starting_odometer, 0 ].max
      end
    end

    # What the odometer moved but the miles guard would not vouch for — almost
    # always a missed fill-up or a mistyped reading. Surfaced so the shortfall is
    # visible instead of quietly deflating total miles and inflating cost per
    # mile.
    def uncounted_miles(scope = all)
      [ tracked_span(scope) - total_miles(scope), 0 ].max
    end

    # --- MPG -----------------------------------------------------------------

    def overall_mpg(scope = all)
      intervals = mpg_intervals(scope)
      return nil if intervals.empty?

      total_miles = intervals.sum { |interval| interval[:miles] }
      total_gallons = intervals.sum { |interval| interval[:gallons] }
      return nil if total_miles <= 0 || total_gallons <= 0

      (total_miles.to_f / total_gallons).round(2)
    end

    def avg_mpg_last(scope = all, n = 10)
      intervals = mpg_intervals(scope)
        .sort_by { |interval| [ interval[:fuel_date], interval[:id] ] }
        .last(n)

      return nil if intervals.empty?

      (intervals.sum { |interval| interval[:mpg] } / intervals.size).round(2)
    end

    def mpg_intervals(scope = all)
      mileage_intervals(scope).select { |interval| plausible_mpg?(interval) }
    end

    # Only counts intervals that recorded gallons — an interval with no gallons
    # was never a candidate for MPG, so reporting it as "ignored" would read as
    # an error the driver needs to fix.
    def excluded_mpg_interval_count(scope = all)
      odometer_intervals(scope).count do |interval|
        interval[:gallons].positive? && !(plausible_miles?(interval) && plausible_mpg?(interval))
      end
    end

    def total_gallons(scope = all)
      scope.sum(:gallons).to_f
    end

    # Reference only. Fuel spend that reaches the P&L comes from Expense records
    # so a fill-up recorded in both places is not counted twice; see
    # OperatingSummary.
    def total_cost(scope = all)
      scope.sum(:total_cost).to_f
    end

    # --- Interval construction -----------------------------------------------

    def odometer_intervals(scope = all)
      logs = scope.where.not(odometer: nil)
        .reorder(:truck_id, :odometer, :fuel_date, :id)
        .to_a
      return [] if logs.empty?

      trucks = Truck.where(id: logs.map(&:truck_id).uniq).index_by(&:id)

      # Grouped by truck so one truck's odometer is never differenced against
      # another's.
      logs.group_by(&:truck_id).flat_map do |truck_id, truck_logs|
        intervals = truck_logs.each_cons(2).filter_map do |previous_log, current_log|
          interval_between(previous_log, current_log)
        end

        leading = baseline_interval(trucks[truck_id], truck_logs.first)
        leading ? intervals.unshift(leading) : intervals
      end
    end

    def interval_between(previous_log, current_log)
      return nil if previous_log&.odometer.blank? || current_log&.odometer.blank?

      build_interval(previous_log.odometer, current_log)
    end

    # A truck's very first fill-up has no preceding reading, so its miles would
    # otherwise be lost forever. The truck's baseline_odometer stands in as that
    # starting point. Applied only when the log really is the truck's earliest,
    # so a date-filtered report never absorbs miles driven before its period.
    def baseline_interval(truck, first_log)
      starting_odometer = baseline_start_for(truck, first_log)
      return nil unless starting_odometer

      # Miles only. The gallons on that first fill-up paid for driving done
      # before tracking started, and there is no way to know how full the tank
      # was at the baseline reading, so any MPG derived from it would be fiction.
      build_interval(starting_odometer, first_log, include_fuel: false)
    end

    # The truck's baseline reading, but only when it can legitimately stand in as
    # the starting point for this log — that is, the log really is the truck's
    # earliest, so a date-filtered report never absorbs miles from before it.
    def baseline_start_for(truck, first_log)
      return nil if truck&.baseline_odometer.blank?
      return nil if first_log&.odometer.blank?
      return nil if truck.fuel_logs.where(odometer: ...first_log.odometer).exists?

      truck.baseline_odometer
    end

    def plausible_miles?(interval)
      return false unless interval

      interval[:miles].positive? && interval[:miles] <= MAX_INTERVAL_MILES
    end

    def plausible_mpg?(interval)
      return false unless interval
      return false if interval[:mpg].blank?

      interval[:mpg] <= MAX_REASONABLE_MPG
    end

    def valid_mpg_interval?(interval)
      plausible_miles?(interval) && plausible_mpg?(interval)
    end

    private

    def build_interval(starting_odometer, current_log, include_fuel: true)
      miles = current_log.odometer - starting_odometer
      gallons = include_fuel ? current_log.gallons.to_f : 0.0
      mpg = (miles.to_f / gallons).round(2) if miles.positive? && gallons.positive?

      {
        id: current_log.id || 0,
        fuel_date: current_log.fuel_date || Date.new(1, 1, 1),
        miles: miles,
        gallons: gallons,
        mpg: mpg
      }
    end
  end

  private

  def interval_since_last_fill
    return @interval_since_last_fill if defined?(@interval_since_last_fill)

    @interval_since_last_fill = begin
      if truck.blank? || odometer.blank?
        nil
      else
        previous_log = truck.fuel_logs.where(odometer: ...odometer).order(odometer: :desc).first

        interval = if previous_log
          self.class.interval_between(previous_log, self)
        else
          self.class.baseline_interval(truck, self)
        end

        self.class.plausible_miles?(interval) ? interval : nil
      end
    end
  end
end
