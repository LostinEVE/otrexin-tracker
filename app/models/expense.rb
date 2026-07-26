class Expense < ApplicationRecord
  # Expenses are the only record of money spent, so this list has to cover
  # everything — including fuel and repairs, which are also logged (without
  # dollars reaching the P&L) in FuelLog and Maintenance.
  CATEGORIES = {
    "fuel" => "Fuel",
    "maintenance" => "Maintenance & Repairs",
    "tolls" => "Tolls & Parking",
    "food" => "Food & Meals",
    "insurance" => "Insurance",
    "permits" => "Permits & Licenses",
    "truck_payment" => "Truck Payment / Lease",
    "trailer_lease" => "Trailer Lease / Rent",
    "loan_payment" => "Loan Payment",
    "settlement_fee" => "Settlement / Broker Fees",
    "escrow" => "Escrow (refundable)",
    "phone_internet" => "Phone & Internet",
    "eld_dashcam" => "ELD & Dash Cam",
    "towing" => "Towing",
    "supplies" => "Supplies",
    "drivers_pay" => "Drivers Pay",
    "truck_wash_hopper_washout" => "Truck Wash / Hopper Washout",
    "other" => "Other"
  }.freeze

  # Escrow is a refundable deposit held by the carrier, not money spent. It is
  # recorded so the balance can be seen, but it must not reduce profit or cost
  # per mile the way a real cost does.
  NON_OPERATING_CATEGORIES = %w[ escrow ].freeze

  belongs_to :user
  belongs_to :truck
  belongs_to :settlement_template_line, optional: true
  belongs_to :settlement, optional: true

  scope :operating, -> { where.not(category: NON_OPERATING_CATEGORIES) }
  scope :non_operating, -> { where(category: NON_OPERATING_CATEGORIES) }

  # Category is deliberately not an inclusion validation: records created before
  # this list existed must stay editable.
  validates :expense_date, :category, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :gallons, numericality: { greater_than: 0 }, allow_nil: true

  require "csv"

  def category_label
    self.class.category_label(category)
  end

  def operating?
    !NON_OPERATING_CATEGORIES.include?(category.to_s)
  end

  def self.category_label(category)
    CATEGORIES.fetch(category.to_s) { category.to_s.humanize }
  end

  def self.to_csv(records)
    CSV.generate(headers: true) do |csv|
      csv << [ "Truck", "Date", "Category", "Vendor", "Amount", "Gallons", "Notes" ]
      records.each do |expense|
        csv << [
          expense.truck&.display_name,
          expense.expense_date,
          expense.category,
          expense.vendor,
          expense.amount,
          expense.gallons,
          expense.notes
        ]
      end
    end
  end
end
