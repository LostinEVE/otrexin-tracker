class PerDiemEntry < ApplicationRecord
  belongs_to :user
  belongs_to :truck, optional: true

  validates :start_date, :end_date, :qualifying_days, :daily_rate, presence: true
  validates :qualifying_days, numericality: { greater_than: 0, only_integer: true }
  validates :daily_rate, numericality: { greater_than: 0 }
  validate :end_date_not_before_start_date

  def deduction_amount
    (qualifying_days.to_i * daily_rate.to_d).round(2)
  end

  def overlaps_period?(period_start, period_end)
    start_date <= period_end && end_date >= period_start
  end

  private

  def end_date_not_before_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "must be on or after the start date")
  end
end
