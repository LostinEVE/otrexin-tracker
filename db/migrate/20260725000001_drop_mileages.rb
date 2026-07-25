# Trip-by-trip mileage has been replaced: miles now come from fuel log odometer
# readings and revenue comes from paid invoices, so the trip log was a third,
# manually maintained source that could only disagree with the other two.
#
# DESTRUCTIVE. Rolling back restores the table but not the rows in it. Export
# anything worth keeping before running this in production.
class DropMileages < ActiveRecord::Migration[8.1]
  def up
    drop_table :mileages
  end

  def down
    create_table :mileages do |t|
      t.datetime :created_at, null: false
      t.string :destination
      t.string :load_number
      t.decimal :miles
      t.text :notes
      t.string :origin
      t.decimal :revenue
      t.date :trip_date
      t.integer :truck_id, null: false
      t.datetime :updated_at, null: false
      t.integer :user_id, null: false
    end

    add_index :mileages, :trip_date
    add_index :mileages, :truck_id
    add_index :mileages, [ :user_id, :truck_id ]
    add_index :mileages, :user_id
    add_foreign_key :mileages, :trucks
    add_foreign_key :mileages, :users
  end
end
