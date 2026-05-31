class FuelLog < ApplicationRecord
  belongs_to :user
  belongs_to :truck

  validates :odometer, presence: true, numericality: { only_integer: true, greater_than: 0 }

  scope :with_mpg_inputs, -> { where('odometer IS NOT NULL AND gallons IS NOT NULL AND gallons > 0') }

  # Returns miles driven and MPG compared to the PREVIOUS entry by odometer order.
  # Returns nil if there is no previous entry (first fill-up has no reference).
  def mpg_since_last_fill
    return nil unless truck.present? && odometer.present? && gallons.present? && gallons > 0

    prev = truck.fuel_logs.where('odometer < ?', odometer)
                         .order(odometer: :desc)
                         .first
    return nil unless prev&.odometer.present?

    miles = odometer - prev.odometer
    return nil if miles <= 0

    (miles.to_f / gallons).round(2)
  end

  def miles_since_last_fill
    return nil unless truck.present? && odometer.present?

    prev = truck.fuel_logs.where('odometer < ?', odometer)
                         .order(odometer: :desc)
                         .first
    return nil unless prev&.odometer.present?

    miles = odometer - prev.odometer
    miles > 0 ? miles : nil
  end

  # Class-level stats used by the index page
  def self.overall_mpg(scope = all)
    logs = scope.with_mpg_inputs.reorder(:odometer).to_a
    return nil if logs.size < 2

    total_miles  = logs.last.odometer - logs.first.odometer
    total_gallons = logs.sum { |l| l.gallons.to_f }
    return nil if total_miles <= 0 || total_gallons <= 0

    (total_miles.to_f / total_gallons).round(2)
  end

  def self.avg_mpg_last(scope = all, n = 10)
    logs = scope.with_mpg_inputs.reorder(odometer: :desc).limit(n + 1).to_a
    return nil if logs.size < 2

    mpgs = logs.each_cons(2).map do |newer, older|
      miles = newer.odometer - older.odometer
      next nil if miles <= 0
      (miles.to_f / newer.gallons).round(2)
    end.compact

    return nil if mpgs.empty?
    (mpgs.sum / mpgs.size).round(2)
  end

  def self.total_gallons(scope = all)
    scope.sum(:gallons).to_f
  end

  def self.total_cost(scope = all)
    scope.sum(:total_cost).to_f
  end
end
