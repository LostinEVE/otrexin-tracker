class FuelLog < ApplicationRecord
  # An odometer gap wider than this is not miles we can vouch for. Counting it
  # would inflate miles and deflate cost per mile.
  MAX_INTERVAL_MILES = 2_000

  # Past this, a gap is not a missed fill-up at all — no truck runs 25,000 miles
  # between two logged fuel stops. See discontinuity?.
  MAX_PLAUSIBLE_GAP_MILES = 25_000

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

    # A jump so large it cannot be driving: the odometer itself changed. A
    # replacement cluster, a reset, a stretch logged against a trip meter, or a
    # placeholder reading entered because the odometer was not working.
    #
    # The giveaway is scale. A genuine missed fill-up is small next to the
    # reading it follows — 2,500 miles on top of 1,370,000. A scale change is
    # larger than every mile recorded before it, because the number restarted
    # from somewhere else entirely.
    def discontinuity?(interval)
      return false unless interval
      return false unless interval[:miles] > MAX_INTERVAL_MILES

      interval[:miles] > MAX_PLAUSIBLE_GAP_MILES || interval[:miles] > interval[:from].to_i
    end

    def odometer_discontinuity_count(scope = all)
      odometer_intervals(scope).count { |interval| discontinuity?(interval) }
    end

    # Gaps that are too wide to trust but still look like real driving — the
    # signature of a fill-up that was never logged. These are the ones worth
    # chasing, because they are miles the truck almost certainly covered.
    def unverified_intervals(scope = all)
      odometer_intervals(scope).reject do |interval|
        plausible_miles?(interval) || discontinuity?(interval) || interval[:miles] <= 0
      end
    end

    def excluded_mileage_interval_count(scope = all)
      unverified_intervals(scope).size
    end

    # Miles the truck plausibly covered across the logged period: what was
    # counted, plus what looks like real driving we could not verify.
    #
    # Deliberately NOT last odometer minus first. Subtracting across an odometer
    # replacement reports the difference between two unrelated numbering schemes
    # as distance — for a truck whose odometer was swapped that is over a million
    # phantom miles. Building the span from the intervals instead keeps
    # span - counted == uncounted true by construction, so the panel can never
    # contradict itself.
    def tracked_span(scope = all)
      total_miles(scope) + uncounted_miles(scope)
    end

    # Miles that look like real driving but fall outside what the guard will
    # vouch for — the signature of a fill-up that was never logged. Surfaced so
    # the shortfall is visible instead of quietly inflating cost per mile.
    # Odometer discontinuities are excluded: those are not miles at all.
    def uncounted_miles(scope = all)
      unverified_intervals(scope).sum { |interval| interval[:miles] }
    end

    # Fill-ups sharing an odometer reading with the entry before them. They are
    # dropped from both miles and MPG, but they cost no distance, so they must
    # not be reported as missing miles.
    def repeated_odometer_count(scope = all)
      odometer_intervals(scope).count { |interval| interval[:miles].zero? }
    end

    # --- MPG -----------------------------------------------------------------

    def overall_mpg(scope = all)
      intervals = mpg_intervals(scope)
      return nil if intervals.empty?

      total_miles = intervals.sum { |interval| interval[:miles] }
      total_gallons = intervals.sum { |interval| interval[:gallons] }
      return nil if total_miles <= 0 || total_gallons <= 0

      # MPG is a ratio, not money or a stored quantity — float is fine here.
      (total_miles.to_f / total_gallons.to_f).round(2)
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
        next false if discontinuity?(interval)

        interval[:gallons].positive? && !(plausible_miles?(interval) && plausible_mpg?(interval))
      end
    end

    def total_gallons(scope = all)
      scope.sum(:gallons).to_d
    end

    # Reference only. Fuel spend that reaches the P&L comes from Expense records
    # so a fill-up recorded in both places is not counted twice; see
    # OperatingSummary.
    def total_cost(scope = all)
      scope.sum(:total_cost).to_d
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
      # A baseline at or above the first recorded reading cannot be where
      # tracking started — the fuel log already goes back further than it does.
      # This happens when a baseline was guessed or backfilled, and using it
      # anyway would invent a negative interval and understate the real span.
      return nil unless truck.baseline_odometer < first_log.odometer
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
      gallons = include_fuel ? current_log.gallons.to_d : 0.to_d
      # MPG is a ratio, not money or a stored quantity — float is fine here.
      mpg = (miles.to_f / gallons.to_f).round(2) if miles.positive? && gallons.positive?

      {
        id: current_log.id || 0,
        fuel_date: current_log.fuel_date || Date.new(1, 1, 1),
        from: starting_odometer,
        to: current_log.odometer,
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
