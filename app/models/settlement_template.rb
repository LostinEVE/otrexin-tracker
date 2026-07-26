class SettlementTemplate < ApplicationRecord
  belongs_to :user
  belongs_to :truck, optional: true

  has_many :lines, -> { order(:position, :id) },
           class_name: "SettlementTemplateLine",
           dependent: :destroy,
           inverse_of: :settlement_template

  accepts_nested_attributes_for :lines, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true

  # The deduction set a leased owner-operator sees every week, laid out the way a
  # carrier settlement statement lists it: the truck's own deductions first, then
  # the contractor's. Amounts and payoff totals are typical rather than
  # authoritative — every one is editable, and a line that is already paid off
  # ships switched off so it stays visible without being deducted again.
  STARTER_LINES = [
    # Truck deductions
    { label: "KY Permit", category: "permits", amount: 130.00, balance_target: 1_300.00 },
    { label: "Plates", category: "permits", amount: 75.00, balance_target: 2_100.00 },
    { label: "Plates - prior year", category: "permits", amount: 75.00, balance_target: 476.00, active: false },
    { label: "Bobtail Insurance", category: "insurance", amount: 6.92 },
    { label: "Dash Cam", category: "eld_dashcam", amount: 8.50 },
    { label: "E-Log", category: "eld_dashcam", amount: 6.00 },
    { label: "Tractor Physical Damage", category: "insurance", amount: 32.31 },
    # Contractor deductions
    { label: "Contractor Escrow", category: "escrow", amount: 50.00, balance_target: 500.00 },
    { label: "Equipment Loan", category: "loan_payment", amount: 300.00, balance_target: 1_219.31 },
    { label: "Loan Fee", category: "loan_payment", amount: 30.00, balance_target: 121.93 },
    { label: "Trailer Escrow", category: "escrow", amount: 125.00, balance_target: 2_000.00 },
    { label: "Trailer Lease Purchase", category: "trailer_lease", amount: 175.00, balance_target: 62_500.00 },
    { label: "Occupational Accident Insurance", category: "insurance", amount: 33.46 },
    { label: "Trailer Physical Damage", category: "insurance", amount: 15.00 }
  ].freeze

  def self.starter_lines
    STARTER_LINES.each_with_index.map do |line, index|
      SettlementTemplateLine.new(line.merge(position: index))
    end
  end

  def active_lines
    lines.select(&:active?)
  end

  # Total of one run, useful for checking the form against the settlement
  # statement before saving.
  def expected_total
    active_lines.sum { |line| line.amount.to_d }
  end
end
