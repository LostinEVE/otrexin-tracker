require "test_helper"

# Metrics over settlement data. Every expected value is computed by hand from
# the small fixtures each test builds; the June-August window keeps the seeded
# March fixtures out of the figures.
class OperatingSummaryMetricsTest < ActiveSupport::TestCase
  WINDOW_START = Date.new(2026, 6, 1)
  WINDOW_END = Date.new(2026, 8, 31)

  def summary
    OperatingSummary.new(user: users(:one), start_date: WINDOW_START, end_date: WINDOW_END, truck: trucks(:one))
  end

  def settlement!(date, linehaul: 0, rate: nil, advance: 0, miles: nil, number: nil)
    users(:one).settlements.create!(
      truck: trucks(:one), statement_date: date, statement_number: number,
      linehaul: linehaul, fuel_advance: advance, miles: miles,
      realized_linehaul_rate: rate
    )
  end

  def expense!(settlement, category, amount)
    users(:one).expenses.create!(truck: trucks(:one), settlement: settlement,
                                 expense_date: settlement.statement_date,
                                 category: category, amount: amount, vendor: "Kaplan")
  end

  def deduction!(settlement, label, weekly:, balance:, target: nil)
    settlement.settlement_deductions.create!(
      label: label, category: "other", weekly_amount: weekly,
      new_balance: balance, balance_target: target,
      scheduled_amount: weekly || 0, collected_this_statement: weekly || 0
    )
  end

  test "a settlement outside the trailing band is flagged beyond two sigma" do
    # Trailing rates 0.75 and 0.77: mean 0.76, sigma 0.01. A 0.77 week sits
    # 1 sigma out and passes; a 0.79 week sits 3 sigma out and flags.
    settlement!(Date.new(2026, 6, 5), rate: 0.75.to_d, number: "A")
    settlement!(Date.new(2026, 6, 12), rate: 0.77.to_d, number: "B")
    passing = settlement!(Date.new(2026, 6, 19), rate: 0.77.to_d, number: "C")
    flagged = settlement!(Date.new(2026, 6, 26), rate: 0.79.to_d, number: "D")

    outliers = summary.linehaul_rate_outliers
    assert_includes outliers, flagged
    assert_not_includes outliers, passing
  end

  test "an identical history flags any change at all" do
    # All trailing weeks exactly 0.76: sigma is zero, so 0.85 must flag.
    settlement!(Date.new(2026, 6, 5), rate: 0.76.to_d, number: "A")
    settlement!(Date.new(2026, 6, 12), rate: 0.76.to_d, number: "B")
    odd = settlement!(Date.new(2026, 6, 19), rate: 0.85.to_d, number: "C")

    assert_equal [ odd ], summary.linehaul_rate_outliers
  end

  test "deduction rate is everything withheld over truck revenue" do
    settlement = settlement!(Date.new(2026, 7, 3), linehaul: 1_000.00, advance: 100.00, number: "A")
    expense!(settlement, "insurance", 200.00)
    users(:one).escrow_ledger_entries.create!(truck: trucks(:one), settlement: settlement,
                                              name: "Contractor Escrow", entry_date: settlement.statement_date,
                                              deposit_amount: 50.00, running_balance: 50.00)

    # (200 expenses + 50 escrow + 100 advance) / 1,000 revenue.
    assert_equal 0.35.to_d, summary.deduction_rate
  end

  test "fuel share of revenue is the EFS advance over truck revenue" do
    settlement!(Date.new(2026, 7, 3), linehaul: 1_000.00, advance: 300.00, number: "A")

    assert_equal 0.3.to_d, summary.fuel_share_of_revenue
  end

  test "the weekly obligation counts flat and unfinished lines, not finished ones" do
    settlement = settlement!(Date.new(2026, 7, 31), number: "A")
    deduction!(settlement, "Bobtail Insurance", weekly: 6.92, balance: nil)
    deduction!(settlement, "Plates", weekly: 150.00, balance: 1_275.00, target: 2_100.00)
    deduction!(settlement, "Loan", weekly: 300.00, balance: 0.00, target: 1_219.31)

    # 6.92 + 150.00; the finished loan's 300.00 is gone.
    assert_equal 156.92.to_d, summary.weekly_recurring_obligation
  end

  test "the obligation reads the latest settlement, not history" do
    old = settlement!(Date.new(2026, 7, 3), number: "A")
    deduction!(old, "Loan", weekly: 300.00, balance: 319.31, target: 1_219.31)
    latest = settlement!(Date.new(2026, 7, 31), number: "B")
    deduction!(latest, "Loan", weekly: 300.00, balance: 0.00, target: 1_219.31)
    deduction!(latest, "Plates", weekly: 150.00, balance: 1_275.00, target: 2_100.00)

    assert_equal 150.00.to_d, summary.weekly_recurring_obligation
  end

  test "deductions completing within N weeks come from balance over weekly" do
    settlement = settlement!(Date.new(2026, 7, 31), number: "A")
    deduction!(settlement, "Plates", weekly: 150.00, balance: 1_275.00, target: 2_100.00)
    deduction!(settlement, "Trailer Lease", weekly: 175.00, balance: 61_800.00, target: 62_500.00)

    # 1,275 / 150 = 8.5, so the plates finish on the ninth week from here.
    assert_equal [ "Plates" ], summary.deductions_completing_within(9).map(&:label)
    assert_empty summary.deductions_completing_within(8)
  end

  test "fixed and variable cost per mile split by category over paid miles" do
    settlement = settlement!(Date.new(2026, 7, 3), linehaul: 1_000.00, miles: 1_000, number: "A")
    expense!(settlement, "insurance", 100.00)
    expense!(settlement, "fuel", 300.00)

    assert_equal 0.10.to_d, summary.fixed_cost_per_mile
    assert_equal 0.30.to_d, summary.variable_cost_per_mile
    assert_equal 1_000, summary.paid_miles
  end

  test "net revenue per working day divides profit by days the truck ran" do
    settlement = settlement!(Date.new(2026, 7, 3), linehaul: 1_000.00, number: "A")
    expense!(settlement, "fuel", 400.00)
    5.times do |i|
      users(:one).fuel_logs.create!(truck: trucks(:one), fuel_date: Date.new(2026, 7, 6) + i,
                                    odometer: 10_000 + i * 500, gallons: 50)
    end

    # (1,000 - 400) / 5 fueling days.
    assert_equal 120.00.to_d, summary.net_revenue_per_working_day
  end
end
