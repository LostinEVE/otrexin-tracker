class RenameDateToPickupDateInInvoices < ActiveRecord::Migration[8.1]
  def change
    rename_column :invoices, :_date, :pickup_date
  end
end
