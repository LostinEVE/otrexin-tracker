# Money held by the carrier and owed back per the lease — an asset, not a
# cost. Escrow lines on a settlement land here instead of in expenses, so no
# operating aggregate can absorb a refundable deposit by accident.
class EscrowLedgerEntry < ApplicationRecord
  belongs_to :user
  belongs_to :truck, optional: true
  belongs_to :settlement, optional: true

  validates :name, presence: true
  validates :deposit_amount, :running_balance, numericality: { greater_than_or_equal_to: 0 }

  scope :for_period, ->(start_date, end_date) { where(entry_date: start_date..end_date) }
end
