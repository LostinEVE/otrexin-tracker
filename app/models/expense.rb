class Expense < ApplicationRecord
	belongs_to :user

	require "csv"

	def self.to_csv(records)
		CSV.generate(headers: true) do |csv|
			csv << ["Date", "Category", "Vendor", "Amount", "Gallons", "Notes"]
			records.each do |expense|
				csv << [
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
