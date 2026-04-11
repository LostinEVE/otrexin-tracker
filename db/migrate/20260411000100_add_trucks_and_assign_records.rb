class AddTrucksAndAssignRecords < ActiveRecord::Migration[8.1]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"
  end

  class MigrationTruck < ApplicationRecord
    self.table_name = "trucks"
  end

  class MigrationMileage < ApplicationRecord
    self.table_name = "mileages"
  end

  class MigrationFuelLog < ApplicationRecord
    self.table_name = "fuel_logs"
  end

  class MigrationMaintenance < ApplicationRecord
    self.table_name = "maintenances"
  end

  class MigrationExpense < ApplicationRecord
    self.table_name = "expenses"
  end

  class MigrationInvoice < ApplicationRecord
    self.table_name = "invoices"
  end

  def up
    create_table :trucks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :unit_number
      t.string :vin
      t.integer :year
      t.string :make
      t.string :model
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :trucks, [:user_id, :name], unique: true

    add_reference :mileages, :truck, foreign_key: true
    add_reference :fuel_logs, :truck, foreign_key: true
    add_reference :maintenances, :truck, foreign_key: true
    add_reference :expenses, :truck, foreign_key: true
    add_reference :invoices, :truck, foreign_key: true

    add_index :mileages, [:user_id, :truck_id]
    add_index :fuel_logs, [:user_id, :truck_id]
    add_index :maintenances, [:user_id, :truck_id]
    add_index :expenses, [:user_id, :truck_id]
    add_index :invoices, [:user_id, :truck_id]

    backfill_default_trucks

    change_column_null :mileages, :truck_id, false
    change_column_null :fuel_logs, :truck_id, false
    change_column_null :maintenances, :truck_id, false
    change_column_null :expenses, :truck_id, false
    change_column_null :invoices, :truck_id, false
  end

  def down
    remove_index :invoices, [:user_id, :truck_id]
    remove_index :expenses, [:user_id, :truck_id]
    remove_index :maintenances, [:user_id, :truck_id]
    remove_index :fuel_logs, [:user_id, :truck_id]
    remove_index :mileages, [:user_id, :truck_id]

    remove_reference :invoices, :truck, foreign_key: true
    remove_reference :expenses, :truck, foreign_key: true
    remove_reference :maintenances, :truck, foreign_key: true
    remove_reference :fuel_logs, :truck, foreign_key: true
    remove_reference :mileages, :truck, foreign_key: true

    drop_table :trucks
  end

  private

  def backfill_default_trucks
    say_with_time "Creating default trucks and assigning historical records" do
      MigrationUser.find_each do |user|
        truck = MigrationTruck.create!(user_id: user.id, name: "Primary Truck", active: true)

        MigrationMileage.where(user_id: user.id).update_all(truck_id: truck.id)
        MigrationFuelLog.where(user_id: user.id).update_all(truck_id: truck.id)
        MigrationMaintenance.where(user_id: user.id).update_all(truck_id: truck.id)
        MigrationExpense.where(user_id: user.id).update_all(truck_id: truck.id)
        MigrationInvoice.where(user_id: user.id).update_all(truck_id: truck.id)
      end
    end
  end
end