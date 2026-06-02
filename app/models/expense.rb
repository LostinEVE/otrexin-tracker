class Expense < ApplicationRecord
  belongs_to :user
  belongs_to :truck

  validates :expense_date, :category, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :gallons, numericality: { greater_than: 0 }, allow_nil: true

  require "csv"

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
