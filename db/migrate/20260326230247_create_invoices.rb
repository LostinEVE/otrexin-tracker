class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.string :invoice_number
      t.string :pickup
      t.date :_date
      t.date :delivery_date
      t.decimal :amount
      t.string :status
      t.text :notes

      t.timestamps
    end
  end
end
