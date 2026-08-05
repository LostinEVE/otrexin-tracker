require "test_helper"

class DepreciationAssetTest < ActiveSupport::TestCase
  test "section 179 expenses entire basis in first year" do
    asset = depreciation_assets(:section179)

    assert_equal asset.depreciable_basis, asset.deduction_for_year(2026)
    assert_equal 0, asset.deduction_for_year(2027)
  end

  test "double declining balance front loads depreciation" do
    asset = depreciation_assets(:double_declining)

    assert_operator asset.deduction_for_year(2026), :>, asset.deduction_for_year(2027)
  end

  test "a partial period gets its share of the year rather than the whole year" do
    asset = depreciation_assets(:straight_line)

    # 6,000 a year, and Jan 1 through Mar 31 is 90 of 365 days:
    # 6,000 x 90 / 365 = 1,479.452... rounds to 1,479.45.
    assert_equal 6_000.to_d, asset.deduction_for_year(2026)
    assert_equal 1_479.45.to_d, asset.deduction_for_period(Date.new(2026, 1, 1), Date.new(2026, 3, 31))
  end

  test "the yearly deductions of a partial period still add up to the full year" do
    asset = depreciation_assets(:straight_line)

    first_half = asset.deduction_for_period(Date.new(2026, 1, 1), Date.new(2026, 6, 30))
    second_half = asset.deduction_for_period(Date.new(2026, 7, 1), Date.new(2026, 12, 31))

    # 181 days: 6,000 x 181 / 365 = 2,975.342... -> 2,975.34.
    # 184 days: 6,000 x 184 / 365 = 3,024.657... -> 3,024.66.
    assert_equal 2_975.34.to_d, first_half
    assert_equal 3_024.66.to_d, second_half
    assert_equal asset.deduction_for_year(2026), first_half + second_half
  end
end
