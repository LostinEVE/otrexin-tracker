# One accessorial line as the statement printed it: what the customer was
# billed, the percentage passed through, and what reached the truck.
class SettlementAccessorial < ApplicationRecord
  belongs_to :settlement

  validates :label, presence: true
  validates :gross_amount, :net_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :percentage_applied, numericality: { greater_than_or_equal_to: 0 }
end
