class Maintenance < ApplicationRecord
	belongs_to :user
	belongs_to :truck

	require "csv"

	def self.to_csv(records)
		CSV.generate(headers: true) do |csv|
			csv << ["Truck", "Service Date", "Type", "Cost", "Odometer", "Vendor", "Notes"]
			records.each do |maintenance|
				csv << [
					maintenance.truck&.display_name,
					maintenance.maintenance_date,
					maintenance.maintenance_type,
					maintenance.cost,
					maintenance.odometer,
					maintenance.vendor,
					maintenance.notes
				]
			end
		end
	end
end
