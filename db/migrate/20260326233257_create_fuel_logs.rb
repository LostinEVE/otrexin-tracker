class CreateFuelLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :fuel_logs do |t|
      t.date :fuel_date
      t.integer :odometer
      t.decimal :gallons
      t.decimal :price_per_gallon
      t.decimal :total_cost
      t.string :location
      t.string :station
      t.text :notes

      t.timestamps
    end
  end
end
