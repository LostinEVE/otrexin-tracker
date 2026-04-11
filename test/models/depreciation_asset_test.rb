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
end