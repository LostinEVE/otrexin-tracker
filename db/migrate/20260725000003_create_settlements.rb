# A leased owner-operator does not invoice anyone — the carrier settles with
# them. Revenue therefore arrives as line haul plus fuel surcharge plus
# accessorials on a statement, which is also the figure the 1099 reports.
class CreateSettlements < ActiveRecord::Migration[8.1]
  def change
    create_table :settlements do |t|
      t.references :user, null: false, foreign_key: true
      t.references :truck, foreign_key: true
      t.references :settlement_template, foreign_key: true
      t.date :statement_date, null: false
      t.string :statement_number
      t.string :payer
      t.integer :load_count
      # What the customer was billed. Informational only: it is the carrier's
      # revenue, not the driver's, so it never reaches the P&L.
      t.decimal :gross_linehaul, precision: 12, scale: 2, default: "0.0", null: false
      t.decimal :linehaul, precision: 12, scale: 2, default: "0.0", null: false
      t.decimal :fuel_surcharge, precision: 12, scale: 2, default: "0.0", null: false
      t.decimal :accessorials, precision: 12, scale: 2, default: "0.0", null: false
      t.decimal :other_income, precision: 12, scale: 2, default: "0.0", null: false
      t.text :notes
      t.timestamps
    end

    add_index :settlements, [ :user_id, :statement_date ]
    add_reference :expenses, :settlement, foreign_key: true, null: true
  end
end
