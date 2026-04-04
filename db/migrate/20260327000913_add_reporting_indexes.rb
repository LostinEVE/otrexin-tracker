class AddReportingIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :invoices, :invoice_date
    add_index :invoices, :status
    add_index :expenses, :expense_date
    add_index :maintenances, :maintenance_date
    add_index :mileages, :trip_date
  end
end
