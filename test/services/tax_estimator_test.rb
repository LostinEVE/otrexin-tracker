require "test_helper"

class TaxEstimatorTest < ActiveSupport::TestCase
  def paid_invoice_for(user, truck, amount)
    Invoice.create!(
      user: user,
      truck: truck,
      invoice_number: "INV-#{amount.to_i}",
      customer_name: "Big Shipper",
      invoice_date: Date.new(2026, 6, 1),
      amount: amount,
      status: "paid"
    )
  end

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

  test "operating expenses do not add the maintenance log on top of expenses" do
    # users(:two) has an 850 maintenance record and no expenses at all.
    estimator = TaxEstimator.new(user: users(:two), year: 2026)

    assert_equal 0.0, estimator.operating_expenses
  end

  test "self employment tax is charged on 92.35 percent of profit, not the whole profit" do
    paid_invoice_for(users(:two), trucks(:three), 100_000)
    estimator = TaxEstimator.new(user: users(:two), year: 2026)

    profit = estimator.business_profit
    earnings = estimator.net_earnings_from_self_employment

    assert_in_delta profit * 0.9235, earnings, 0.01
    assert_in_delta earnings * 0.153, estimator.self_employment_tax, 0.01
    # The bug this guards against: charging 15.3% on the raw profit, which
    # overstated the bill by roughly 8%.
    assert_operator estimator.self_employment_tax, :<, profit * 0.153
  end

  test "social security stops at the wage base while medicare does not" do
    paid_invoice_for(users(:two), trucks(:three), 400_000)
    estimator = TaxEstimator.new(user: users(:two), year: 2026)

    earnings = estimator.net_earnings_from_self_employment
    wage_base = estimator.social_security_wage_base

    assert_operator earnings, :>, wage_base

    expected = (wage_base * 0.124) + (earnings * 0.029)
    assert_in_delta expected, estimator.self_employment_tax, 0.01
    assert_operator estimator.self_employment_tax, :<, earnings * 0.153
  end

  test "taxable income deducts half the self employment tax and the standard deduction" do
    paid_invoice_for(users(:two), trucks(:three), 100_000)
    estimator = TaxEstimator.new(user: users(:two), year: 2026)

    expected = estimator.business_profit -
      (estimator.self_employment_tax / 2.0) -
      estimator.standard_deduction

    assert_in_delta expected, estimator.taxable_income, 0.01
  end

  test "a loss owes nothing rather than going negative" do
    estimator = TaxEstimator.new(user: users(:one), year: 2026)

    assert_operator estimator.business_profit, :<, 0
    assert_equal 0, estimator.self_employment_tax
    assert_equal 0, estimator.taxable_income
    assert_equal 0, estimator.income_tax
    assert_equal 0, estimator.total_owed
  end

  test "income tax is applied bracket by bracket" do
    estimator = TaxEstimator.new(user: users(:two), year: 2026)
    estimator.define_singleton_method(:taxable_income) { 50_000.0 }

    # 2026 single filer: 10% of the first 12,400, then 12% of the remainder.
    expected = (12_400 * 0.10) + ((50_000 - 12_400) * 0.12)

    assert_in_delta expected, estimator.income_tax, 0.01
  end

  test "an unpublished tax year falls back to the newest table and says so" do
    newest = TaxEstimator::TAX_YEARS.keys.max
    estimator = TaxEstimator.new(user: users(:one), year: 2040)

    assert estimator.estimated_from_other_year?
    assert_equal newest, estimator.table_year
    assert_equal TaxEstimator::TAX_YEARS[newest][:standard_deduction], estimator.standard_deduction
  end

  test "a published tax year is not flagged as a fallback" do
    estimator = TaxEstimator.new(user: users(:one), year: 2026)

    assert_not estimator.estimated_from_other_year?
    assert_equal 2026, estimator.table_year
    assert_equal 16_100, estimator.standard_deduction
  end
end
