class TaxPayment < ApplicationRecord
  belongs_to :user

  validates :payment_date, :quarter, presence: true
  validates :amount, numericality: { greater_than: 0 }

  # Money paid toward one quarter's estimate, exact — these figures sit next
  # to IRS deadlines, so no float ever touches them.
  def self.quarter_total(payments, quarter, year)
    payments
      .select { |payment| payment.quarter == quarter && payment.payment_date&.year == year }
      .sum(0.to_d) { |payment| payment.amount.to_d }
  end
end
