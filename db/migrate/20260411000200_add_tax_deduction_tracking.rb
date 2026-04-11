class AddTaxDeductionTracking < ActiveRecord::Migration[8.1]
  def change
    create_table :per_diem_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :truck, foreign_key: true
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :qualifying_days, null: false
      t.decimal :daily_rate, null: false, precision: 10, scale: 2
      t.text :notes

      t.timestamps
    end

    add_index :per_diem_entries, [:user_id, :start_date]

    create_table :depreciation_assets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :truck, foreign_key: true
      t.string :name, null: false
      t.string :asset_type, null: false
      t.date :placed_in_service_date, null: false
      t.decimal :cost_basis, null: false, precision: 12, scale: 2
      t.decimal :salvage_value, null: false, precision: 12, scale: 2, default: 0
      t.integer :recovery_period_years, null: false
      t.string :depreciation_method, null: false, default: "straight_line"
      t.text :notes

      t.timestamps
    end

    add_index :depreciation_assets, [:user_id, :placed_in_service_date]
  end
end