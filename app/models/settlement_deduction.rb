# One row of the statement's deduction sub-table, as printed. The expenses on
# the settlement remain the reporting layer; this is the detail behind them —
# what was scheduled, what was actually collected, and what balance remains.
class SettlementDeduction < ApplicationRecord
  belongs_to :settlement

  validates :label, :category, presence: true
  validates :scheduled_amount, :collected_this_statement, :uncollected,
            :previous_collected, :total_collected_to_date,
            numericality: { greater_than_or_equal_to: 0 }

  # Reached its payoff target on this statement — the weekly obligation drops.
  def finished?
    new_balance.present? && new_balance.zero?
  end
end
