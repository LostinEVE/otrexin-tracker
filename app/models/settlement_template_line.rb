class SettlementTemplateLine < ApplicationRecord
  belongs_to :settlement_template, inverse_of: :lines
  has_many :expenses, dependent: :nullify

  validates :label, :category, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :balance_target, numericality: { greater_than: 0 }, allow_nil: true

  # What this line has actually taken so far. Read from the expenses it created
  # rather than from the template, so editing a default amount never rewrites
  # history.
  def collected
    expenses.sum(:amount).to_d
  end

  def tracks_balance?
    balance_target.present?
  end

  def remaining
    return nil unless tracks_balance?

    [ balance_target.to_d - collected, 0.to_d ].max
  end

  def paid_off?
    tracks_balance? && remaining.zero?
  end

  def category_label
    Expense.category_label(category)
  end
end
