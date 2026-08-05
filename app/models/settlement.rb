class Settlement < ApplicationRecord
  belongs_to :user
  belongs_to :truck, optional: true
  belongs_to :settlement_template, optional: true

  # The deductions were created by this statement, so removing it removes them.
  has_many :expenses, dependent: :destroy
  has_many :settlement_deductions, dependent: :destroy
  has_many :escrow_ledger_entries, dependent: :destroy

  MONEY_FIELDS = %i[ gross_linehaul linehaul fuel_surcharge accessorials other_income ].freeze

  validates :statement_date, presence: true
  validates(*MONEY_FIELDS, numericality: { greater_than_or_equal_to: 0 })
  validates :load_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :for_period, ->(start_date, end_date) { where(statement_date: start_date..end_date) }

  # What the driver actually earned. Gross linehaul is excluded on purpose: it is
  # what the customer paid the carrier, not what reached the truck.
  def truck_revenue
    linehaul.to_d + fuel_surcharge.to_d + accessorials.to_d + other_income.to_d
  end

  def total_deductions
    expenses.sum(:amount).to_d
  end

  # What actually landed in the bank, matching the settlement balance line. The
  # fuel advance is subtracted even though it is not an expense, because the
  # carrier really did hold it back.
  def net_balance
    truck_revenue - total_deductions - fuel_advance.to_d
  end

  # Everything the carrier withheld, expensed or not.
  def total_withheld
    total_deductions + fuel_advance.to_d
  end

  # The carrier's cut, when the gross was recorded.
  def linehaul_percentage
    return nil unless gross_linehaul.to_d.positive?

    (linehaul.to_d / gross_linehaul.to_d * 100).round(1)
  end
end
