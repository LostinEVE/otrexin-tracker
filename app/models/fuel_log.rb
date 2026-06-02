class FuelLog < ApplicationRecord
  MAX_MPG_INTERVAL_MILES = 2_000
  MAX_REASONABLE_MPG = 15.0

  belongs_to :user
  belongs_to :truck

  validates :fuel_date, presence: true
  validates :odometer, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :gallons, numericality: { greater_than: 0 }, allow_nil: true
  validates :price_per_gallon, :total_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :with_mpg_inputs, -> { where("odometer IS NOT NULL AND gallons IS NOT NULL AND gallons > 0") }

  # Returns miles driven and MPG compared to the PREVIOUS entry by odometer order.
  # Returns nil if there is no previous entry (first fill-up has no reference).
  def mpg_since_last_fill
    mpg_interval_since_last_fill&.fetch(:mpg)
  end

  def miles_since_last_fill
    mpg_interval_since_last_fill&.fetch(:miles)
  end

  def self.total_miles_safe(scope = all)
    total = mpg_intervals(scope).sum { |interval| interval[:miles] }

    total > 0 ? total : nil
  end

  # Class-level stats used by the index page
  def self.overall_mpg(scope = all)
    intervals = mpg_intervals(scope)
    return nil if intervals.empty?

    total_miles = intervals.sum { |interval| interval[:miles] }
    total_gallons = intervals.sum { |interval| interval[:gallons] }
    return nil if total_miles <= 0 || total_gallons <= 0

    (total_miles.to_f / total_gallons).round(2)
  end

  def self.avg_mpg_last(scope = all, n = 10)
    intervals = mpg_intervals(scope)
      .sort_by { |interval| [ interval[:fuel_date], interval[:id] ] }
      .last(n)

    return nil if intervals.empty?
    (intervals.sum { |interval| interval[:mpg] } / intervals.size).round(2)
  end

  def self.total_gallons(scope = all)
    scope.sum(:gallons).to_f
  end

  def self.total_cost(scope = all)
    scope.sum(:total_cost).to_f
  end

  def self.excluded_mpg_interval_count(scope = all)
    raw_mpg_intervals(scope).count { |interval| !valid_mpg_interval?(interval) }
  end

  def self.mpg_intervals(scope = all)
    raw_mpg_intervals(scope).select { |interval| valid_mpg_interval?(interval) }
  end

  def self.raw_mpg_intervals(scope = all)
    logs = scope.where.not(odometer: nil)
      .reorder(:truck_id, :odometer, :fuel_date, :id)
      .to_a

    logs.group_by(&:truck_id).values.flat_map do |truck_logs|
      truck_logs.each_cons(2).filter_map do |previous_log, current_log|
        mpg_interval_between(previous_log, current_log)
      end
    end
  end

  def self.mpg_interval_between(previous_log, current_log)
    return nil unless previous_log&.odometer.present?
    return nil unless current_log&.odometer.present?
    return nil unless current_log.gallons.present? && current_log.gallons.positive?

    miles = current_log.odometer - previous_log.odometer
    mpg = miles.to_f / current_log.gallons.to_f if miles.positive?

    {
      id: current_log.id || 0,
      fuel_date: current_log.fuel_date || Date.new(1, 1, 1),
      miles: miles,
      gallons: current_log.gallons.to_f,
      mpg: mpg&.round(2)
    }
  end

  def self.valid_mpg_interval?(interval)
    return false unless interval
    return false unless interval[:miles].positive?
    return false if interval[:miles] > MAX_MPG_INTERVAL_MILES
    return false unless interval[:mpg].present?
    return false if interval[:mpg] > MAX_REASONABLE_MPG

    true
  end

  private

  def mpg_interval_since_last_fill
    return nil unless truck.present? && odometer.present?

    previous_log = truck.fuel_logs.where("odometer < ?", odometer)
      .order(odometer: :desc)
      .first

    interval = self.class.mpg_interval_between(previous_log, self)
    return nil unless self.class.valid_mpg_interval?(interval)

    interval
  end
end
