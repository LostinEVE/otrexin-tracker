class HomeController < ApplicationController
  def index
    today = Date.today
    month_start = today.beginning_of_month
    year_start  = Date.new(today.year, 1, 1)
    truck_filter = selected_truck

    invoice_scope = current_user.invoices
    invoice_scope = invoice_scope.where(truck: truck_filter) if truck_filter

    expense_scope = current_user.expenses
    expense_scope = expense_scope.where(truck: truck_filter) if truck_filter

    fuel_scope = current_user.fuel_logs
    fuel_scope = fuel_scope.where(truck: truck_filter) if truck_filter

    # Invoices
    @unpaid_total  = invoice_scope.where(status: 'unpaid').sum(:amount)
    @paid_mtd      = invoice_scope.where(status: 'paid').where('invoice_date >= ?', month_start).sum(:amount)
    @ytd_revenue   = invoice_scope.where(status: 'paid').where('invoice_date >= ?', year_start).sum(:amount)

    # Expenses
    @expenses_mtd  = expense_scope.where('expense_date >= ?', month_start).sum(:amount)
    @ytd_expenses  = expense_scope.where('expense_date >= ?', year_start).sum(:amount)
    @expenses_by_category_mtd = expense_scope
      .where('expense_date >= ?', month_start)
      .group(:category).sum(:amount)
      .sort_by { |_k, v| -v.to_f }

    # Historical miles and metrics
    historical_miles = 20468
    @historical_cpm = historical_miles > 0 ? (expense_scope.sum(:amount).to_f / historical_miles).round(4) : nil

    # Miles from baseline odometer forward
    baseline_odo = truck_filter&.baseline_odometer || 0
    fuel_logs_after_baseline = fuel_scope.where('odometer IS NOT NULL').where('odometer >= ?', baseline_odo).order(:odometer)
    fuel_max_odo = fuel_logs_after_baseline.maximum(:odometer).to_f
    fuel_new_miles = baseline_odo > 0 && fuel_max_odo > baseline_odo ? (fuel_max_odo - baseline_odo) : 0

    @total_miles = fuel_new_miles.round
    total_paid_revenue = invoice_scope.where(status: 'paid').sum(:amount).to_f
    @rpm = fuel_new_miles > 0 ? (total_paid_revenue / fuel_new_miles).round(4) : nil
    @cpm = fuel_new_miles > 0 ? (expense_scope.sum(:amount).to_f / fuel_new_miles).round(4) : nil

    # Fuel
    @overall_mpg = FuelLog.overall_mpg(fuel_scope)

    # Recent unpaid invoices
    @recent_unpaid = invoice_scope.where(status: 'unpaid').order(invoice_date: :desc).limit(5)
  end
end
