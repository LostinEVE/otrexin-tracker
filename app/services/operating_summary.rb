# Single source of truth for every money figure the app reports.
#
# Expenses are the only record of what was spent. Fuel logs supply odometer
# readings, and therefore miles; maintenance records are service history. Neither
# contributes dollars, because a fill-up or a repair is routinely entered as an
# expense as well, and adding both sides would count it twice.
#
# The dashboard, the P&L, and the tax estimator all read from here so they cannot
# drift apart.
class OperatingSummary
  # How far apart a fuel/maintenance record and an expense row can sit and still
  # be considered the same real-world transaction.
  MATCH_WINDOW_DAYS = 7

  attr_reader :user, :truck, :start_date, :end_date

  def initialize(user:, start_date:, end_date:, truck: nil)
    @user = user
    @truck = truck
    @start_date = start_date
    @end_date = end_date
  end

  def self.year(user:, year:, truck: nil)
    new(user: user, start_date: Date.new(year, 1, 1), end_date: Date.new(year, 12, 31), truck: truck)
  end

  # --- Money -----------------------------------------------------------------

  # Both earning shapes are counted and shown separately: a leased driver is paid
  # on carrier settlements, an independent one invoices customers. Keeping the
  # two lines distinct means a figure entered twice is visible rather than hidden
  # inside one total.
  def revenue
    invoice_revenue + settlement_revenue
  end

  def invoice_revenue
    @invoice_revenue ||= paid_invoices.sum(:amount).to_d
  end

  def settlement_revenue
    @settlement_revenue ||= settlements.sum { |settlement| settlement.truck_revenue }.to_d
  end

  # Paid specifically to offset diesel, so it belongs against fuel rather than
  # sitting anonymously in revenue.
  def fuel_surcharge_total
    @fuel_surcharge_total ||= settlements.sum { |settlement| settlement.fuel_surcharge.to_d }.to_d
  end

  def fuel_expense_total
    @fuel_expense_total ||= expenses.where(category: "fuel").sum(:amount).to_d
  end

  # What diesel actually cost after the surcharge covered part of it.
  def net_fuel_cost
    fuel_expense_total - fuel_surcharge_total
  end

  def net_fuel_cost_per_mile
    per_mile(net_fuel_cost)
  end

  # The carrier prints a running 1099 total on every statement. Comparing the
  # books against the most recent one is the closest thing to an independent
  # audit available before the 1099 itself arrives: it catches a statement never
  # imported, and income counted twice.
  def latest_ytd_statement
    return @latest_ytd_statement if defined?(@latest_ytd_statement)

    @latest_ytd_statement = scoped_to_truck(user.settlements.where.not(ytd_revenue: nil))
      .where(statement_date: ..end_date)
      .order(:statement_date).last
  end

  def carrier_ytd_revenue
    latest_ytd_statement&.ytd_revenue&.to_d
  end

  # Revenue recorded for the same year the carrier's figure covers.
  def revenue_to_compare
    return nil if latest_ytd_statement.nil?

    year = latest_ytd_statement.statement_date.year
    OperatingSummary.year(user: user, year: year, truck: truck).revenue
  end

  def ytd_difference
    return nil if carrier_ytd_revenue.nil?

    revenue_to_compare - carrier_ytd_revenue
  end

  def load_count
    @load_count ||= settlements.sum { |settlement| settlement.load_count.to_i }
  end

  # Escrow is deliberately absent. It is a refundable deposit, not a cost, so
  # counting it here would understate profit and overstate cost per mile.
  def expense_total
    @expense_total ||= expenses.operating.sum(:amount).to_d
  end

  def expense_by_category
    @expense_by_category ||= expenses.operating.group(:category).sum(:amount)
      .sort_by { |_category, amount| -amount.to_d }
  end

  # Money handed to the carrier and still owed back to you.
  def escrow_total
    @escrow_total ||= expenses.non_operating.sum(:amount).to_d
  end

  # Escrow accumulates across the whole relationship, not just this report
  # period, so the running balance ignores the date filter.
  def escrow_balance
    @escrow_balance ||= scoped_to_truck(user.expenses.non_operating).sum(:amount).to_d
  end

  def net_profit
    revenue - expense_total
  end

  # --- Miles -----------------------------------------------------------------

  def total_miles
    @total_miles ||= FuelLog.total_miles(fuel_logs)
  end

  def cost_per_mile
    per_mile(expense_total)
  end

  def revenue_per_mile
    per_mile(revenue)
  end

  def profit_per_mile
    per_mile(net_profit)
  end

  # --- Tax adjustments -------------------------------------------------------

  def per_diem_total
    @per_diem_total ||= per_diem_entries.sum { |entry| entry.deduction_for_period(start_date, end_date) }.to_d
  end

  def depreciation_total
    @depreciation_total ||= depreciation_assets.sum { |asset| asset.deduction_for_period(start_date, end_date) }.to_d
  end

  def tax_adjustment_total
    per_diem_total + depreciation_total
  end

  def taxable_profit_estimate
    net_profit - tax_adjustment_total
  end

  # --- Reconciliation --------------------------------------------------------
  #
  # Fuel logs and maintenance records still carry a cost field, but only expenses
  # reach the P&L. The question worth answering is "did any cost I logged never
  # make it into my books?", and that is a comparison of totals — a driver who
  # enters one weekly fuel expense covering five fill-ups has lost nothing, and
  # should not be nagged about it. Only when the logs total more than the
  # expenses is money genuinely missing, and the per-record lists below then show
  # which entries to look at first.

  def logged_fuel_cost
    @logged_fuel_cost ||= priced_fuel_logs.sum(:total_cost).to_d
  end

  def recorded_fuel_expense
    @recorded_fuel_expense ||= expenses.where(category: "fuel").sum(:amount).to_d
  end

  def logged_maintenance_cost
    @logged_maintenance_cost ||= priced_maintenances.sum(:cost).to_d
  end

  def recorded_maintenance_expense
    @recorded_maintenance_expense ||= expenses.where(category: "maintenance").sum(:amount).to_d
  end

  def fuel_cost_gap
    [ logged_fuel_cost - recorded_fuel_expense, 0.to_d ].max
  end

  def maintenance_cost_gap
    [ logged_maintenance_cost - recorded_maintenance_expense, 0.to_d ].max
  end

  def unreconciled_total
    fuel_cost_gap + maintenance_cost_gap
  end

  def reconciled?
    unreconciled_total.zero?
  end

  # Detail behind the gap: the individual records with no expense that lines up
  # with them. Shown only when there is a gap to explain.
  def unmatched_fuel_logs
    return [] if fuel_cost_gap.zero?

    @unmatched_fuel_logs ||= unmatched(
      priced_fuel_logs.to_a,
      expenses.where(category: "fuel"),
      :fuel_date,
      :total_cost
    )
  end

  def unmatched_maintenances
    return [] if maintenance_cost_gap.zero?

    @unmatched_maintenances ||= unmatched(
      priced_maintenances.to_a,
      expenses.where(category: "maintenance"),
      :maintenance_date,
      :cost
    )
  end

  # --- Scopes ----------------------------------------------------------------

  def paid_invoices
    scoped_to_truck(user.invoices.where(status: "paid", invoice_date: start_date..end_date))
  end

  def settlements
    @settlements ||= scoped_to_truck(user.settlements.for_period(start_date, end_date)).to_a
  end

  def expenses
    scoped_to_truck(user.expenses.where(expense_date: start_date..end_date))
  end

  def fuel_logs
    scoped_to_truck(user.fuel_logs.where(fuel_date: start_date..end_date))
  end

  def priced_fuel_logs
    fuel_logs.includes(:truck).where.not(total_cost: nil).where("total_cost > 0").order(:fuel_date)
  end

  def priced_maintenances
    scoped_to_truck(user.maintenances.where(maintenance_date: start_date..end_date))
      .includes(:truck).where.not(cost: nil).where("cost > 0").order(:maintenance_date)
  end

  def per_diem_entries
    scoped_to_truck(user.per_diem_entries)
      .select { |entry| entry.overlaps_period?(start_date, end_date) }
  end

  def depreciation_assets
    scoped_to_truck(user.depreciation_assets.where(placed_in_service_date: ..end_date))
  end

  private

  def scoped_to_truck(scope)
    truck ? scope.where(truck: truck) : scope
  end

  def per_mile(amount)
    return nil unless total_miles.positive?

    (amount / total_miles).round(4)
  end

  # Pairs each record against at most one expense, so two fill-ups on the same
  # day for the same amount are not both cleared by a single expense row.
  def unmatched(records, expense_scope, date_method, amount_method)
    remaining = expense_scope.pluck(:truck_id, :expense_date, :amount)

    records.reject do |record|
      index = remaining.index do |truck_id, expense_date, amount|
        truck_id == record.truck_id &&
          amount.to_d == record.public_send(amount_method).to_d &&
          (expense_date - record.public_send(date_method)).abs <= MATCH_WINDOW_DAYS
      end

      remaining.delete_at(index) if index
      !index.nil?
    end
  end
end
