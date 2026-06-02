class TaxPayment < ApplicationRecord
  belongs_to :user

  validates :payment_date, :quarter, presence: true
  validates :amount, numericality: { greater_than: 0 }
end
