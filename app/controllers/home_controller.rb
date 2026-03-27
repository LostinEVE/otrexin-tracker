class HomeController < ApplicationController
  def index
    today = Date.today
    month_start = today.beginning_of_month
    year_start  = Date.new(today.year, 1, 1)

    # Invoices
    @unpaid_total  = Invoice.where(status: 'unpaid').sum(:amount)
    @paid_mtd      = Invoice.where(status: 'paid').where('invoice_date >= ?', month_start).sum(:amount)
    @ytd_revenue   = Invoice.where(status: 'paid').where('invoice_date >= ?', year_start).sum(:amount)

    # Expenses
    @expenses_mtd  = Expense.where('expense_date >= ?', month_start).sum(:amount)
    @ytd_expenses  = Expense.where('expense_date >= ?', year_start).sum(:amount)

    # Mileage / CPM
    @total_miles   = Mileage.total_miles
    @cpm           = Mileage.cost_per_mile
    @rpm           = Mileage.overall_revenue_per_mile

    # Fuel
    @overall_mpg   = FuelLog.overall_mpg

    # Recent unpaid invoices
    @recent_unpaid = Invoice.where(status: 'unpaid').order(invoice_date: :desc).limit(5)
  end
end
