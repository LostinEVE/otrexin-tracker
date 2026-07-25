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

  # --- Miles -----------------------------------------------------------------

  test "total miles is the odometer distance between fill ups" do
    assert_equal 500, FuelLog.total_miles(FuelLog.where(truck: trucks(:one)))
  end

  test "a single fill up cannot produce miles" do
    assert_equal 0, FuelLog.total_miles(FuelLog.where(truck: trucks(:two)))
  end

  test "miles are counted even when gallons were not recorded" do
    truck = trucks(:one)
    FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 4, 3), odometer: 1_800)

    truck_scope = FuelLog.where(truck: truck)

    # The 300 mile stretch counts toward miles driven, but contributes no MPG
    # and is not reported as an interval the driver needs to fix.
    assert_equal 800, FuelLog.total_miles(truck_scope)
    assert_equal 10.0, FuelLog.overall_mpg(truck_scope)
    assert_equal 0, FuelLog.excluded_mpg_interval_count(truck_scope)
  end

  test "implausible odometer jumps are left out of total miles" do
    truck = trucks(:one)
    FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 4, 1), odometer: 90_000, gallons: 30)

    truck_scope = FuelLog.where(truck: truck)

    assert_equal 500, FuelLog.total_miles(truck_scope)
    assert_equal 1, FuelLog.excluded_mileage_interval_count(truck_scope)
  end

  test "a backwards odometer reading does not subtract miles" do
    truck = trucks(:one)
    FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 4, 1), odometer: 1_200, gallons: 30)

    # Readings sort by odometer, so 1,000 to 1,200 to 1,500 still totals 500.
    assert_equal 500, FuelLog.total_miles(FuelLog.where(truck: truck))
  end

  test "miles across trucks are summed but never differenced" do
    FuelLog.create!(user: users(:one), truck: trucks(:two), fuel_date: Date.new(2026, 4, 2), odometer: 2_400, gallons: 40)

    # Truck one contributes 500 and truck two contributes 400. The 500 unit gap
    # between the two trucks' odometers is never treated as distance driven.
    assert_equal 900, FuelLog.total_miles(FuelLog.where(user: users(:one)))
  end

  # --- Baseline odometer -----------------------------------------------------

  test "baseline odometer recovers the miles before the first fill up" do
    truck = trucks(:one)
    truck.update!(baseline_odometer: 900)

    truck_scope = FuelLog.where(truck: truck)

    assert_equal 600, FuelLog.total_miles(truck_scope)
    # That first fill-up's gallons paid for driving done before tracking began,
    # so the baseline stretch must not move MPG.
    assert_equal 10.0, FuelLog.overall_mpg(truck_scope)
  end

  test "a baseline odometer far below the first reading is ignored" do
    truck = Truck.create!(user: users(:one), name: "Fresh Truck", baseline_odometer: 1)
    FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 5, 1), odometer: 500_000, gallons: 100)
    FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 5, 8), odometer: 500_600, gallons: 60)

    # The 499,999 mile leading gap is nonsense and gets dropped by the same cap
    # that guards every other interval. The real 600 mile interval still counts.
    assert_equal 600, FuelLog.total_miles(FuelLog.where(truck: truck))
  end

  test "a baseline within the plausible range is trusted even if it is a rough guess" do
    # A baseline of 1 against a first reading of 1,000 is a 999 mile leading
    # interval, which is under the cap and so counts. The cap only rejects gaps
    # that could not plausibly have been driven between two fill-ups.
    trucks(:one).update!(baseline_odometer: 1)

    assert_equal 1_499, FuelLog.total_miles(FuelLog.where(truck: trucks(:one)))
  end

  test "a baseline odometer ahead of the first reading is ignored" do
    trucks(:one).update!(baseline_odometer: 5_000)

    assert_equal 500, FuelLog.total_miles(FuelLog.where(truck: trucks(:one)))
  end

  test "baseline miles do not leak into a period that starts later" do
    truck = trucks(:one)
    truck.update!(baseline_odometer: 900)

    later_scope = FuelLog.where(truck: truck).where(fuel_date: Date.new(2026, 3, 25)..)

    # Only the 3/27 fill-up falls in range and an earlier one exists outside it,
    # so this period has no measurable distance of its own.
    assert_equal 0, FuelLog.total_miles(later_scope)
  end
end
