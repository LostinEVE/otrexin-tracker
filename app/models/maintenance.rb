class Maintenance < ApplicationRecord
  belongs_to :user
  belongs_to :truck

  validates :maintenance_date, :maintenance_type, presence: true
  validates :cost, numericality: { greater_than: 0 }
  validates :odometer, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  require "csv"

  def self.to_csv(records)
    CSV.generate(headers: true) do |csv|
      csv << [ "Truck", "Service Date", "Type", "Cost", "Odometer", "Vendor", "Notes" ]
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
