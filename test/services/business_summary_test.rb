require "test_helper"

# Every expected value is computed by hand from the small fixture each test
# builds. The June window keeps the seeded March/April fixtures out of the
# figures. The standing scenario:
#
#   Window 06/01-06/28 2026 — 28 days, exactly 4 weeks.
#   Two settlements: 1,000.00 revenue and 500 paid miles each.
#   Fixed costs:    insurance 280.00           ->  70.00/week
#   Variable costs: fuel 800.00 + maintenance 400.00 = 1,200.00 -> 1.20/mile
#   Revenue/mile:   2,000.00 / 1,000 mi        ->   2.00
class BusinessSummaryTest < ActiveSupport::TestCase
  WINDOW_START = Date.new(2026, 6, 1)
  WINDOW_END = Date.new(2026, 6, 28)

  def business
    BusinessSummary.new(user: users(:one), start_date: WINDOW_START, end_date: WINDOW_END,
                        truck: trucks(:one))
  end

  def settlement!(date, linehaul:, miles:, number:)
    users(:one).settlements.create!(truck: trucks(:one), statement_date: date,
                                    statement_number: number, linehaul: linehaul, miles: miles)
  end

  def expense!(settlement, category, amount)
    users(:one).expenses.create!(truck: trucks(:one), settlement: settlement,
                                 expense_date: settlement.statement_date,
                                 category: category, amount: amount, vendor: "Test")
  end

  def build_standing_scenario
    a = settlement!(Date.new(2026, 6, 5), linehaul: 1_000.00, miles: 500, number: "A")
    b = settlement!(Date.new(2026, 6, 12), linehaul: 1_000.00, miles: 500, number: "B")
    expense!(a, "insurance", 280.00)
    expense!(b, "fuel", 800.00)
    expense!(b, "maintenance", 400.00)
    [ a, b ]
  end

  test "weekly fixed costs spread the fixed categories over the window" do
    build_standing_scenario

    # 280.00 of insurance over 4 weeks.
    assert_equal 70.00.to_d, business.weekly_fixed_costs
  end

  test "revenue per paid mile is settlement revenue over settlement miles" do
    build_standing_scenario

    assert_equal 2.00.to_d, business.revenue_per_paid_mile
  end

  test "contribution margin is revenue less variable cost per mile" do
    build_standing_scenario

    # 2.00 - 1.20 (fuel 800 + maintenance 400 over 1,000 miles).
    assert_equal 0.80.to_d, business.contribution_margin_per_mile
  end

  test "break-even miles per week comes from fixed costs over contribution" do
    build_standing_scenario

    # 70.00 / 0.80 = 87.5 miles -> the 88th mile is the first profitable one.
    assert_equal 88, business.break_even_miles_per_week
  end

  test "net margin per mile subtracts every operating cost" do
    build_standing_scenario

    # 2.00 - (280 + 1,200) / 1,000 = 2.00 - 1.48.
    assert_equal 0.52.to_d, business.net_margin_per_mile
  end

  test "maintenance run rate and reserve come from the window's own spend" do
    build_standing_scenario

    # 400.00 over 4 weeks; 0.40 per mile; 12 weeks of run rate to hold back.
    assert_equal 100.00.to_d, business.maintenance_weekly_run_rate
    assert_equal 0.40.to_d, business.maintenance_cost_per_mile
    assert_equal 1_200.00.to_d, business.maintenance_reserve_target
  end

  test "category shares are exact fractions of operating spend" do
    build_standing_scenario

    shares = business.category_shares.to_h { |row| [ row[:category], row[:share] ] }
    # 800 / 1,480 = 0.54054054... -> 0.5405; 400 / 1,480 -> 0.2703;
    # 280 / 1,480 = 0.18918918... -> 0.1892.
    assert_equal "0.5405".to_d, shares["fuel"]
    assert_equal "0.2703".to_d, shares["maintenance"]
    assert_equal "0.1892".to_d, shares["insurance"]
  end

  test "the settlement trend carries each week's own figures" do
    build_standing_scenario

    rows = business.settlement_rows
    assert_equal %w[ B A ], rows.map { |row| row[:settlement].statement_number }

    newest = rows.first
    assert_equal 2.00.to_d, newest[:revenue_per_mile]
    # B carries 1,200.00 of deductions against 1,000.00 revenue.
    assert_equal 1.20.to_d, newest[:deduction_rate]
    assert_equal 0.28.to_d, rows.last[:deduction_rate]
  end

  test "an empty window answers with nothing rather than zero-division" do
    assert_nil business.revenue_per_paid_mile
    assert_nil business.contribution_margin_per_mile
    assert_nil business.net_margin_per_mile
    assert_nil business.break_even_miles_per_week
    assert_equal 0.to_d, business.weekly_fixed_costs
  end

  test "a negative margin has no break-even to report" do
    a = settlement!(Date.new(2026, 6, 5), linehaul: 500.00, miles: 500, number: "A")
    expense!(a, "fuel", 800.00)

    # Revenue 1.00/mile, variable 1.60/mile: no mileage makes that profitable.
    assert_nil business.break_even_miles_per_week
  end
end
