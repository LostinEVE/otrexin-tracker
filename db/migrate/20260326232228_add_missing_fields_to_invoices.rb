class AddMissingFieldsToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :customer_name, :string
    add_column :invoices, :load_number, :string
    add_column :invoices, :invoice_date, :date
    add_column :invoices, :product_description, :string
    add_column :invoices, :piece_count, :integer
    add_column :invoices, :rate_per_piece, :decimal
  end
end
