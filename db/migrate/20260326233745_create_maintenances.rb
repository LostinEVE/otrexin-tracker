class CreateMaintenances < ActiveRecord::Migration[8.1]
  def change
    create_table :maintenances do |t|
      t.date :maintenance_date
      t.string :maintenance_type
      t.decimal :cost
      t.integer :odometer
      t.string :vendor
      t.text :notes

      t.timestamps
    end
  end
end
