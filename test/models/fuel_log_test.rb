require "test_helper"

class FuelLogTest < ActiveSupport::TestCase
  test "mpg stats stay scoped to one truck" do
    truck_scope = FuelLog.where(truck: trucks(:one))
    other_scope = FuelLog.where(truck: trucks(:two))

    assert_equal 10.0, FuelLog.overall_mpg(truck_scope)
    assert_nil FuelLog.overall_mpg(other_scope)
  end

  test "mpg stats ignore unrealistic odometer repair jumps" do
    truck = trucks(:one)

    FuelLog.create!(
      user: users(:one),
      truck: truck,
      fuel_date: Date.new(2026, 4, 1),
      odometer: 90_000,
      gallons: 30,
      total_cost: 120
    )

    FuelLog.create!(
      user: users(:one),
      truck: truck,
      fuel_date: Date.new(2026, 4, 8),
      odometer: 90_500,
      gallons: 50,
      total_cost: 200
    )

    truck_scope = FuelLog.where(truck: truck)

    assert_equal 10.0, FuelLog.overall_mpg(truck_scope)
    assert_equal 10.0, FuelLog.avg_mpg_last(truck_scope)
    assert_equal 1, FuelLog.excluded_mpg_interval_count(truck_scope)
  end

  test "mpg stats do not compare odometers across trucks" do
    all_user_logs = FuelLog.where(user: users(:one))

    assert_equal 10.0, FuelLog.overall_mpg(all_user_logs)
  end
end
