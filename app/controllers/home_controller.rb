class HomeController < ApplicationController
  def index
    today = Date.today
    month_start = today.beginning_of_month
    year_start  = Date.new(today.year, 1, 1)

    # Invoices
    @unpaid_total  = current_user.invoices.where(status: 'unpaid').sum(:amount)
    @paid_mtd      = current_user.invoices.where(status: 'paid').where('invoice_date >= ?', month_start).sum(:amount)
    @ytd_revenue   = current_user.invoices.where(status: 'paid').where('invoice_date >= ?', year_start).sum(:amount)

    # Expenses
    @expenses_mtd  = current_user.expenses.where('expense_date >= ?', month_start).sum(:amount)
    @ytd_expenses  = current_user.expenses.where('expense_date >= ?', year_start).sum(:amount)

    # Mileage / CPM
    @total_miles = current_user.mileages.sum(:miles).to_f
    total_revenue = current_user.mileages.sum(:revenue).to_f
    @rpm = @total_miles.positive? ? (total_revenue / @total_miles).round(4) : nil
    @cpm = @total_miles.positive? ? (current_user.expenses.sum(:amount).to_f / @total_miles).round(4) : nil

    # Fuel
    logs = current_user.fuel_logs.order(:odometer).where('odometer IS NOT NULL AND gallons IS NOT NULL AND gallons > 0').to_a
    if logs.size > 1
      total_miles = logs.last.odometer - logs.first.odometer
      total_gallons = logs.sum { |l| l.gallons.to_f }
      @overall_mpg = total_miles > 0 && total_gallons > 0 ? (total_miles.to_f / total_gallons).round(2) : nil
    else
      @overall_mpg = nil
    end

    # Recent unpaid invoices
    @recent_unpaid = current_user.invoices.where(status: 'unpaid').order(invoice_date: :desc).limit(5)
  end
end
