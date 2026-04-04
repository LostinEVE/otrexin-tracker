class CreateTaxPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :tax_payments do |t|
      t.date :payment_date
      t.string :quarter
      t.decimal :amount
      t.text :notes

      t.timestamps
    end
  end
end
