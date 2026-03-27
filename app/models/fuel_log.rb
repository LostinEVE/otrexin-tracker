class FuelLog < ApplicationRecord
  belongs_to :user

  # Returns miles driven and MPG compared to the PREVIOUS entry by odometer order.
  # Returns nil if there is no previous entry (first fill-up has no reference).
  def mpg_since_last_fill
    return nil unless odometer.present? && gallons.present? && gallons > 0

    prev = FuelLog.where('odometer < ?', odometer)
                  .order(odometer: :desc)
                  .first
    return nil unless prev&.odometer.present?

    miles = odometer - prev.odometer
    return nil if miles <= 0

    (miles.to_f / gallons).round(2)
  end

  def miles_since_last_fill
    return nil unless odometer.present?

    prev = FuelLog.where('odometer < ?', odometer)
                  .order(odometer: :desc)
                  .first
    return nil unless prev&.odometer.present?

    miles = odometer - prev.odometer
    miles > 0 ? miles : nil
  end

  # Class-level stats used by the index page
  def self.overall_mpg
    logs = order(:odometer).where('odometer IS NOT NULL AND gallons IS NOT NULL AND gallons > 0').to_a
    return nil if logs.size < 2

    total_miles  = logs.last.odometer - logs.first.odometer
    total_gallons = logs.sum { |l| l.gallons.to_f }
    return nil if total_miles <= 0 || total_gallons <= 0

    (total_miles.to_f / total_gallons).round(2)
  end

  def self.avg_mpg_last(n = 10)
    logs = order(odometer: :desc).where('odometer IS NOT NULL AND gallons IS NOT NULL AND gallons > 0').limit(n + 1).to_a
    return nil if logs.size < 2

    mpgs = logs.each_cons(2).map do |newer, older|
      miles = newer.odometer - older.odometer
      next nil if miles <= 0
      (miles.to_f / newer.gallons).round(2)
    end.compact

    return nil if mpgs.empty?
    (mpgs.sum / mpgs.size).round(2)
  end
end
