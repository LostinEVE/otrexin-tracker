require "test_helper"

class TaxEstimatorTest < ActiveSupport::TestCase
  test "includes per diem and depreciation in business profit" do
    estimator = TaxEstimator.new(user: users(:one), year: 2026)

    assert_equal 5_000.0, estimator.revenue
    assert_equal 1_650.0, estimator.operating_expenses
    assert_equal 1_050.0, estimator.per_diem_deductions
    assert_equal 15_000.0, estimator.depreciation_deductions
    assert_equal(-12_700.0, estimator.business_profit)
  end

  test "can filter by truck" do
    estimator = TaxEstimator.new(user: users(:one), year: 2026, truck: trucks(:one))

    assert_equal 5_000.0, estimator.revenue
    assert_equal 1_100.0, estimator.operating_expenses
    assert_equal 1_050.0, estimator.per_diem_deductions
    assert_equal 6_000.0, estimator.depreciation_deductions
    assert_equal(-3_150.0, estimator.business_profit)
  end
end