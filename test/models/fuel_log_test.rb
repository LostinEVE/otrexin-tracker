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
    # A repair jump is the odometer changing, not a fill-up anyone forgot, so it
    # is reported as a break rather than as an unbelievable MPG figure.
    assert_equal 1, FuelLog.odometer_discontinuity_count(truck_scope)
    assert_equal 0, FuelLog.excluded_mpg_interval_count(truck_scope)
  end

  test "an over cap gap on a high odometer is reported as an unbelievable mpg" do
    truck = trucks(:one)
    # 3,000 miles on top of a 900,000 reading: small next to it, so this reads as
    # a skipped fill-up rather than the odometer being swapped.
    FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 4, 1), odometer: 900_000, gallons: 30)
    FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 4, 8), odometer: 903_000, gallons: 50)

    truck_scope = FuelLog.where(truck: truck)

    assert_equal 1, FuelLog.excluded_mpg_interval_count(truck_scope)
    assert_equal 3_000, FuelLog.uncounted_miles(truck_scope)
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
    # The odometer restarted rather than the truck driving 88,500 unlogged miles,
    # so nothing is reported as missing.
    assert_equal 1, FuelLog.odometer_discontinuity_count(truck_scope)
    assert_equal 0, FuelLog.uncounted_miles(truck_scope)
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

  # --- Tracked span vs counted miles -----------------------------------------

  test "a clean run counts every mile the odometer moved" do
    truck = Truck.create!(user: users(:one), name: "Long Hauler", baseline_odometer: 1_371_354)
    odometer = 1_371_354
    12.times do |index|
      odometer += 1_190
      FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 1, 1) + (index * 7),
                      odometer: odometer, gallons: 170)
    end

    scope = FuelLog.where(truck: truck)

    assert_equal 1_385_634, odometer
    assert_equal 14_280, FuelLog.tracked_span(scope)
    assert_equal 14_280, FuelLog.total_miles(scope)
    assert_equal 0, FuelLog.uncounted_miles(scope)
    assert_equal 0, FuelLog.excluded_mileage_interval_count(scope)
  end

  test "a missed fill up leaves a visible shortfall rather than silently shrinking miles" do
    truck = Truck.create!(user: users(:one), name: "Gap Hauler", baseline_odometer: 1_371_354)
    # Three clean 1,000 mile legs, then a 3,600 mile jump where a fill-up went
    # unlogged, then one more clean leg.
    [ 1_372_354, 1_373_354, 1_374_354, 1_377_954, 1_378_954 ].each_with_index do |odometer, index|
      FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 2, 1) + (index * 7),
                      odometer: odometer, gallons: 150)
    end

    scope = FuelLog.where(truck: truck)

    assert_equal 7_600, FuelLog.tracked_span(scope)
    assert_equal 4_000, FuelLog.total_miles(scope)
    assert_equal 3_600, FuelLog.uncounted_miles(scope)
    assert_equal 1, FuelLog.excluded_mileage_interval_count(scope)
  end

  test "tracked span starts at the baseline when one is set" do
    truck = Truck.create!(user: users(:one), name: "Baselined", baseline_odometer: 1_371_354)
    FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 3, 1), odometer: 1_372_000, gallons: 90)
    FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 3, 8), odometer: 1_372_900, gallons: 120)

    scope = FuelLog.where(truck: truck)

    # 646 from the baseline to the first fill, then 900 between the two fills.
    assert_equal 1_546, FuelLog.tracked_span(scope)
    assert_equal 1_546, FuelLog.total_miles(scope)
    assert_equal 0, FuelLog.uncounted_miles(scope)
  end

  # A truck that ran on a placeholder reading, then a trip meter, then a
  # replacement odometer reading 1.37M. The two jumps are the odometer changing,
  # not distance driven, and must not be reported as missing miles.
  BLUEBONNET_ODOMETERS = [
    1, 6_078, 6_636, 7_398, 9_321, 10_086, 10_789, 11_857, 12_931, 13_730, 14_464,
    15_653, 16_551, 17_494, 18_528, 19_172, 20_007, 20_906, 22_134, 23_011, 23_835, 24_617,
    1_369_605, 1_369_778, 1_370_357, 1_370_791, 1_371_354, 1_372_140, 1_373_019, 1_373_945,
    1_374_506, 1_375_299, 1_376_218, 1_376_908, 1_377_738, 1_378_483, 1_379_150, 1_379_834,
    1_380_692, 1_381_500, 1_382_057, 1_382_725, 1_383_431, 1_384_281, 1_385_051, 1_385_631
  ].freeze

  def bluebonnet_scope(baseline: 1_371_354)
    truck = Truck.create!(user: users(:one), name: "Bluebonnet", baseline_odometer: baseline)
    BLUEBONNET_ODOMETERS.each_with_index do |odometer, index|
      FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 2, 12) + (index * 3),
                      odometer: odometer, gallons: 150)
    end
    FuelLog.where(truck: truck)
  end

  test "an odometer replacement is not reported as missing miles" do
    scope = bluebonnet_scope

    # 18,539 on the old numbering plus 16,026 on the new one.
    assert_equal 34_565, FuelLog.total_miles(scope)
    assert_equal 0, FuelLog.uncounted_miles(scope)
    assert_equal 2, FuelLog.odometer_discontinuity_count(scope)
    assert_equal 0, FuelLog.excluded_mileage_interval_count(scope)
  end

  test "the span never contradicts the counted miles" do
    scope = bluebonnet_scope

    # Subtracting last from first would claim 1,385,630 miles and report over a
    # million as missing.
    assert_equal FuelLog.total_miles(scope), FuelLog.tracked_span(scope)
    assert_equal(
      FuelLog.tracked_span(scope) - FuelLog.total_miles(scope),
      FuelLog.uncounted_miles(scope)
    )
  end

  test "a missed fill-up is still reported even alongside an odometer change" do
    scope = bluebonnet_scope
    truck = scope.first.truck
    # 4,500 miles on top of 1,385,631: small next to the reading it follows, so
    # this is a skipped fill-up rather than the odometer changing.
    FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 8, 1),
                    odometer: 1_390_131, gallons: 150)

    reloaded = FuelLog.where(truck: truck)

    assert_equal 4_500, FuelLog.uncounted_miles(reloaded)
    assert_equal 1, FuelLog.excluded_mileage_interval_count(reloaded)
    assert_equal 2, FuelLog.odometer_discontinuity_count(reloaded)
    assert_equal 34_565 + 4_500, FuelLog.tracked_span(reloaded)
  end

  test "a baseline that sits inside the recorded range is ignored" do
    # A backfilled or guessed baseline can land in the middle of a fuel log that
    # already goes back further. Trusting it would invent a negative leading
    # interval and report a span shorter than the miles actually counted.
    truck = Truck.create!(user: users(:one), name: "Backfilled", baseline_odometer: 1_371_354)
    [ 1_351_066, 1_352_200, 1_353_300 ].each_with_index do |odometer, index|
      FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 4, 1) + index,
                      odometer: odometer, gallons: 160)
    end

    scope = FuelLog.where(truck: truck)

    assert_equal 2_234, FuelLog.tracked_span(scope)
    assert_equal 2_234, FuelLog.total_miles(scope)
    assert_equal 0, FuelLog.uncounted_miles(scope)
    assert_equal 0, FuelLog.excluded_mileage_interval_count(scope)
  end

  test "counted miles never exceed the tracked span" do
    truck = Truck.create!(user: users(:one), name: "Consistency", baseline_odometer: 1_371_354)
    [ 1_351_066, 1_352_200, 1_355_900, 1_357_000 ].each_with_index do |odometer, index|
      FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 4, 1) + index,
                      odometer: odometer, gallons: 160)
    end

    scope = FuelLog.where(truck: truck)
    span = FuelLog.tracked_span(scope)
    counted = FuelLog.total_miles(scope)

    assert_operator counted, :<=, span
    assert_equal span - counted, FuelLog.uncounted_miles(scope)
  end

  test "a repeated odometer reading costs no miles and is reported on its own" do
    truck = Truck.create!(user: users(:one), name: "Duplicate")
    [ 1_351_066, 1_352_200, 1_352_200, 1_353_300 ].each_with_index do |odometer, index|
      FuelLog.create!(user: users(:one), truck: truck, fuel_date: Date.new(2026, 4, 1) + index,
                      odometer: odometer, gallons: 160)
    end

    scope = FuelLog.where(truck: truck)

    assert_equal 1, FuelLog.repeated_odometer_count(scope)
    # The duplicate is dropped from miles and MPG but costs no distance, so it
    # must not surface as missing miles.
    assert_equal 2_234, FuelLog.tracked_span(scope)
    assert_equal 2_234, FuelLog.total_miles(scope)
    assert_equal 0, FuelLog.uncounted_miles(scope)
  end

  test "tracked span ignores the baseline when earlier readings exist outside the scope" do
    truck = trucks(:one)
    truck.update!(baseline_odometer: 900)

    later_scope = FuelLog.where(truck: truck).where(fuel_date: Date.new(2026, 3, 25)..)

    assert_equal 0, FuelLog.tracked_span(later_scope)
    assert_equal 0, FuelLog.uncounted_miles(later_scope)
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
