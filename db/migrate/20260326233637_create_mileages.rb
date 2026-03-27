class CreateMileages < ActiveRecord::Migration[8.1]
  def change
    create_table :mileages do |t|
      t.date :trip_date
      t.string :load_number
      t.string :origin
      t.string :destination
      t.decimal :miles
      t.decimal :revenue
      t.text :notes

      t.timestamps
    end
  end
end
