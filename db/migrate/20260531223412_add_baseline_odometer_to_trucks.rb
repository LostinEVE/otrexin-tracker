class AddBaselineOdometerToTrucks < ActiveRecord::Migration[8.1]
  def change
    add_column :trucks, :baseline_odometer, :integer
  end
end
