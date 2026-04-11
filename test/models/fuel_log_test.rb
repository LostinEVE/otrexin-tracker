require "test_helper"

class FuelLogTest < ActiveSupport::TestCase
  test "mpg stats stay scoped to one truck" do
    truck_scope = FuelLog.where(truck: trucks(:one))
    other_scope = FuelLog.where(truck: trucks(:two))

    assert_equal 5.0, FuelLog.overall_mpg(truck_scope)
    assert_nil FuelLog.overall_mpg(other_scope)
  end
end
