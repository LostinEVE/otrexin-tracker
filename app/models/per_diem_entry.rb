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

  # A trip that straddles a period boundary — Dec 28 to Jan 3, say — must not
  # deduct in full on both sides of it, so the qualifying days are spread evenly
  # across the trip and only the overlapping share is claimed.
  def deduction_for_period(period_start, period_end)
    (qualifying_days_within(period_start, period_end) * daily_rate.to_d).round(2)
  end

  def qualifying_days_within(period_start, period_end)
    return 0 unless overlaps_period?(period_start, period_end)
    return qualifying_days.to_i if start_date >= period_start && end_date <= period_end

    overlap_days = ([ end_date, period_end ].min - [ start_date, period_start ].max).to_i + 1
    return 0 if overlap_days <= 0

    span_days = (end_date - start_date).to_i + 1
    [ (qualifying_days.to_i * overlap_days.to_d / span_days).round, qualifying_days.to_i ].min
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
