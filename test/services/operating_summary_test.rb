require "test_helper"

class OperatingSummaryTest < ActiveSupport::TestCase
  def summary_for(truck: nil, start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31))
    OperatingSummary.new(user: users(:one), start_date: start_date, end_date: end_date, truck: truck)
  end

  test "revenue counts paid invoices only" do
    # 2,000 + 3,000 paid; the 1,650 unpaid invoice must not appear.
    assert_equal 5_000.to_d, summary_for.revenue
  end

  test "operating cost is expenses alone and never adds the maintenance log on top" do
    # Expenses total 800 + 300 + 550. The 400 maintenance record is service
    # history, not a second charge.
    assert_equal 1_650.to_d, summary_for.expense_total
    assert_equal 3_350.to_d, summary_for.net_profit
  end

  test "expense categories add up to the expense total" do
    total = summary_for.expense_by_category.sum { |_category, amount| amount.to_d }

    assert_equal summary_for.expense_total, total
  end

  test "miles come from fuel odometer readings" do
    # Truck one fills at 1,000 then 1,500. Truck two has a single fill and so
    # cannot produce an interval.
    assert_equal 500, summary_for.total_miles
  end

  test "cost per mile divides total expenses by fuel derived miles" do
    assert_equal 3.3.to_d, summary_for.cost_per_mile
    assert_equal 10.0.to_d, summary_for.revenue_per_mile
    assert_equal 6.7.to_d, summary_for.profit_per_mile
  end

  test "per mile figures are nil rather than zero when no miles can be derived" do
    summary = summary_for(truck: trucks(:two))

    assert_equal 0, summary.total_miles
    assert_nil summary.cost_per_mile
    assert_nil summary.revenue_per_mile
  end

  test "truck filter scopes money and miles together" do
    summary = summary_for(truck: trucks(:one))

    assert_equal 5_000.to_d, summary.revenue
    assert_equal 1_100.to_d, summary.expense_total
    assert_equal 500, summary.total_miles
    assert_equal 2.2.to_d, summary.cost_per_mile
  end

  test "date range excludes records outside the period" do
    summary = summary_for(start_date: Date.new(2026, 4, 1), end_date: Date.new(2026, 4, 30))

    assert_equal 3_000.to_d, summary.revenue
    assert_equal 0.to_d, summary.expense_total
  end

  test "another user's records never leak in" do
    summary = summary_for

    assert_equal 1_650.to_d, summary.expense_total
    assert_equal 1_050.to_d, summary.per_diem_total
    # users(:two) has an 850 maintenance record and a 360 per diem entry.
    assert_equal 400.to_d, summary.logged_maintenance_cost
  end

  test "batched expenses covering several fill ups are not reported as a gap" do
    # 705 of fuel is logged and 800 recorded as a single fuel expense; 400 of
    # maintenance is logged and 550 recorded. Nothing is missing.
    summary = summary_for

    assert_equal 705.to_d, summary.logged_fuel_cost
    assert_equal 800.to_d, summary.recorded_fuel_expense
    assert_equal 0.to_d, summary.fuel_cost_gap
    assert summary.reconciled?
    assert_empty summary.unmatched_fuel_logs
  end

  test "a logged cost with no expense behind it is reported as a gap" do
    summary = summary_for(truck: trucks(:one))

    # Truck one has a 400 service record and no maintenance expense at all.
    assert_equal 400.to_d, summary.maintenance_cost_gap
    assert_equal 400.to_d, summary.unreconciled_total
    assert_not summary.reconciled?
    assert_includes summary.unmatched_maintenances, maintenances(:one)
  end

  test "the gap never goes negative when expenses exceed the logs" do
    summary = summary_for(truck: trucks(:one))

    # 405 of fuel logged against an 800 fuel expense.
    assert_equal 0.to_d, summary.fuel_cost_gap
  end

  test "one expense clears only one of two identical fuel logs" do
    truck = trucks(:two)
    2.times do |index|
      FuelLog.create!(
        user: users(:one),
        truck: truck,
        fuel_date: Date.new(2026, 5, 1 + index),
        odometer: 2_100 + (index * 100),
        gallons: 40,
        total_cost: 175
      )
    end

    Expense.create!(
      user: users(:one),
      truck: truck,
      expense_date: Date.new(2026, 5, 1),
      category: "fuel",
      amount: 175,
      vendor: "Pilot"
    )

    summary = summary_for(truck: truck)
    assert_operator summary.fuel_cost_gap, :>, 0.to_d

    matching = summary.unmatched_fuel_logs.select { |log| log.total_cost.to_d == 175.to_d }

    assert_equal 1, matching.size
  end

  test "taxable profit estimate subtracts per diem and depreciation" do
    summary = summary_for

    assert_equal 1_050.to_d, summary.per_diem_total
    assert_equal 15_000.to_d, summary.depreciation_total
    assert_equal(-12_700.to_d, summary.taxable_profit_estimate)
  end
end
