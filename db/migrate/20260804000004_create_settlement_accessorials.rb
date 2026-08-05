# Each accessorial as printed, with its stated rate. Stored per line because a
# single aggregate makes the rate unrecoverable — and a 100% accessorial
# quietly reclassified to 76% undetectable.
class CreateSettlementAccessorials < ActiveRecord::Migration[8.1]
  def change
    create_table :settlement_accessorials do |t|
      t.references :settlement, null: false, foreign_key: true
      t.string :label, null: false
      t.decimal :gross_amount, precision: 12, scale: 2, default: "0.0", null: false
      t.decimal :percentage_applied, precision: 6, scale: 3, null: false
      t.decimal :net_amount, precision: 12, scale: 2, default: "0.0", null: false
      t.timestamps
    end

    # The realized percentages, computed at import from the statement's own
    # figures. Historical rows stay null until re-imported.
    add_column :settlements, :realized_linehaul_rate, :decimal, precision: 10, scale: 8
    add_column :settlements, :realized_fuel_surcharge_rate, :decimal, precision: 10, scale: 8
    # nil when every pay line checks out; otherwise says exactly what deviated.
    add_column :settlements, :pay_deviation, :text
  end
end
