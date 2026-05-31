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

    # Miles from fuel log odometer range
    fuel_logs_ordered = fuel_scope.where('odometer IS NOT NULL').order(:odometer)
    fuel_min_odo = fuel_logs_ordered.first&.odometer.to_f
    fuel_max_odo = fuel_logs_ordered.last&.odometer.to_f
    fuel_log_miles = fuel_max_odo - fuel_min_odo

    @total_miles = fuel_log_miles.round
    total_paid_revenue = invoice_scope.where(status: 'paid').sum(:amount).to_f
    @rpm = fuel_log_miles > 0 ? (total_paid_revenue / fuel_log_miles).round(4) : nil
    @cpm = fuel_log_miles > 0 ? (expense_scope.sum(:amount).to_f / fuel_log_miles).round(4) : nil

    # Fuel
    @overall_mpg = FuelLog.overall_mpg(fuel_scope)

    # Recent unpaid invoices
    @recent_unpaid = invoice_scope.where(status: 'unpaid').order(invoice_date: :desc).limit(5)
  end
end
