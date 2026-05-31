class SetBaselineOdometerForTrucks < ActiveRecord::Migration[8.1]
  def change
    Truck.update_all(baseline_odometer: 1371354)
  end
end
