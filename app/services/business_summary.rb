# The business-manager view of a period: what a week must earn, where the
# margin goes, and what to hold back. Reads everything through
# OperatingSummary so it can never disagree with the P&L, and computes
# nothing in a view — every figure here is a tested method.
#
# Money is BigDecimal throughout. Per-mile figures are rounded to 4 places,
# weekly money to 2. A question with no data answers nil, never zero.
class BusinessSummary
  # How many weeks of maintenance run-rate to hold in reserve.
  MAINTENANCE_RESERVE_WEEKS = 12

  attr_reader :user, :truck, :start_date, :end_date, :summary

  def initialize(user:, start_date:, end_date:, truck: nil)
    @user = user
    @truck = truck
    @start_date = start_date
    @end_date = end_date
    @summary = OperatingSummary.new(user: user, start_date: start_date, end_date: end_date, truck: truck)
  end

  delegate :paid_miles, :settlement_revenue, :expense_total, :variable_cost_per_mile,
           :fixed_cost_per_mile, :weekly_recurring_obligation, :deductions_completing_within,
           :escrow_balance, :expense_by_category,
           to: :summary

  # Calendar weeks in the window, as an exact fraction of days.
  def weeks
    ((end_date - start_date).to_i + 1).to_d / 7
  end

  # What comes out every week whether the truck moves or not.
  def weekly_fixed_costs
    (fixed_expense_total / weeks).round(2)
  end

  def revenue_per_paid_mile
    return nil unless paid_miles.positive?

    (settlement_revenue / paid_miles).round(4)
  end

  # What each mile earns after the costs that scale with driving.
  def contribution_margin_per_mile
    revenue = revenue_per_paid_mile
    variable = variable_cost_per_mile
    return nil if revenue.nil? || variable.nil?

    revenue - variable
  end

  # The mileage a week must cover before fixed costs are paid — the first
  # profitable mile is the one after this. Unanswerable when nothing earns.
  def break_even_miles_per_week
    margin = contribution_margin_per_mile
    return nil if margin.nil? || !margin.positive?

    (weekly_fixed_costs / margin).ceil
  end

  # What each mile earns after every operating cost, fixed and variable.
  def net_margin_per_mile
    revenue = revenue_per_paid_mile
    return nil if revenue.nil?

    revenue - (expense_total / paid_miles).round(4)
  end

  def maintenance_weekly_run_rate
    (maintenance_total / weeks).round(2)
  end

  def maintenance_cost_per_mile
    return nil unless paid_miles.positive?

    (maintenance_total / paid_miles).round(4)
  end

  # A reserve sized from what maintenance actually costs, not a rule of thumb.
  def maintenance_reserve_target(reserve_weeks = MAINTENANCE_RESERVE_WEEKS)
    (maintenance_weekly_run_rate * reserve_weeks).round(2)
  end

  # Where the operating money goes, largest first, each with its exact share.
  def category_shares
    total = expense_total
    expense_by_category.map do |category, amount|
      share = total.positive? ? (amount.to_d / total).round(4) : 0.to_d
      { category: category, amount: amount.to_d, share: share }
    end
  end

  # One row per settlement, newest first: what that week earned per mile and
  # how much of it the carrier withheld.
  def settlement_rows
    summary.settlements.sort_by(&:statement_date).reverse.map do |settlement|
      miles = settlement.miles.to_i
      revenue = settlement.truck_revenue

      {
        settlement: settlement,
        revenue: revenue,
        miles: miles,
        revenue_per_mile: miles.positive? ? (revenue / miles).round(4) : nil,
        deduction_rate: revenue.positive? ? (settlement.total_withheld / revenue).round(4) : nil
      }
    end
  end

  private

  def fixed_expense_total
    summary.expenses.operating.where(category: Expense::FIXED_CATEGORIES).sum(:amount).to_d
  end

  def maintenance_total
    summary.expenses.where(category: "maintenance").sum(:amount).to_d
  end
end
