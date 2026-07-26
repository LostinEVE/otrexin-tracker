class AddFuelAdvanceToSettlements < ActiveRecord::Migration[8.1]
  def change
    # Fuel bought on the carrier's card and recovered on the statement. Held on
    # the settlement so the balance reconciles, but not an expense: the driver
    # already records the fuel receipts, and counting both would double the
    # largest cost on the books.
    add_column :settlements, :fuel_advance, :decimal, precision: 12, scale: 2, default: "0.0", null: false
    add_column :settlements, :source_filename, :string
    add_index :settlements, [ :user_id, :statement_number ]
  end
end
