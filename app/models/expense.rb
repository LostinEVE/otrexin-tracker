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
    "supplies" => "Supplies",
    "drivers_pay" => "Drivers Pay",
    "truck_wash_hopper_washout" => "Truck Wash / Hopper Washout",
    "other" => "Other"
  }.freeze

  belongs_to :user
  belongs_to :truck

  # Category is deliberately not an inclusion validation: records created before
  # this list existed must stay editable.
  validates :expense_date, :category, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :gallons, numericality: { greater_than: 0 }, allow_nil: true

  require "csv"

  def category_label
    self.class.category_label(category)
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
