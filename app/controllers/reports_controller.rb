class ReportsController < ApplicationController
  # The business-manager page. Defaults to the trailing thirteen weeks so a
  # carrier change months back cannot quietly distort the run rates.
  def business
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : @end_date - 90

    if @end_date < @start_date
      return redirect_to reports_business_path, alert: "End date must be on or after the start date."
    end

    @business = BusinessSummary.new(
      user: current_user,
      start_date: @start_date,
      end_date: @end_date,
      truck: selected_truck
    )
    @tax = TaxEstimator.new(user: current_user, year: @end_date.year, truck: selected_truck)
    @first_settlement_date = current_user.settlements.minimum(:statement_date)
  rescue Date::Error
    redirect_to reports_business_path, alert: "Invalid date range."
  end

  def profit_loss
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current.beginning_of_year
    @end_date   = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current

    if @end_date < @start_date
      return redirect_to reports_profit_loss_path, alert: "End date must be on or after the start date."
    end

    @summary = OperatingSummary.new(
      user: current_user,
      start_date: @start_date,
      end_date: @end_date,
      truck: selected_truck
    )

    respond_to do |format|
      format.html
      format.csv do
        send_data(
          build_profit_loss_csv,
          filename: "profit-loss-#{@start_date}-to-#{@end_date}.csv",
          type: "text/csv"
        )
      end
    end
  rescue Date::Error
    redirect_to reports_profit_loss_path, alert: "Invalid date range."
  end

  private

  def build_profit_loss_csv
    CSV.generate(headers: true) do |csv|
      csv << [ "OTR Tracker Profit & Loss" ]
      csv << [ "Period", "#{@start_date} to #{@end_date}" ]
      csv << [ "Truck", selected_truck&.display_name || "All trucks" ]
      csv << []
      csv << [ "Summary", "Amount" ]
      csv << [ "Revenue (paid invoices)", amount_cell(@summary.revenue) ]
      csv << [ "Operating Expenses", amount_cell(@summary.expense_total) ]
      csv << [ "Net Profit", amount_cell(@summary.net_profit) ]
      csv << []
      csv << [ "Per Diem Deductions", amount_cell(@summary.per_diem_total) ]
      csv << [ "Depreciation Deductions", amount_cell(@summary.depreciation_total) ]
      csv << [ "Tax Adjustment Total", amount_cell(@summary.tax_adjustment_total) ]
      csv << [ "Taxable Profit Estimate", amount_cell(@summary.taxable_profit_estimate) ]
      csv << []
      csv << [ "Total Miles (from fuel odometer)", @summary.total_miles ]
      csv << [ "Revenue per Mile", amount_cell(@summary.revenue_per_mile, precision: 3) ]
      csv << [ "Cost per Mile", amount_cell(@summary.cost_per_mile, precision: 3) ]
      csv << [ "Profit per Mile", amount_cell(@summary.profit_per_mile, precision: 3) ]
      csv << []
      csv << [ "Expense Category", "Amount" ]
      @summary.expense_by_category.each do |category, amount|
        csv << [ Expense.category_label(category), amount_cell(amount) ]
      end

      next if @summary.reconciled?

      csv << []
      csv << [ "Unreconciled records (logged with a cost but no matching expense)" ]
      csv << [ "Type", "Date", "Truck", "Amount" ]
      @summary.unmatched_fuel_logs.each do |log|
        csv << [ "Fuel log", log.fuel_date, log.truck&.display_name, amount_cell(log.total_cost) ]
      end
      @summary.unmatched_maintenances.each do |record|
        csv << [ "Maintenance", record.maintenance_date, record.truck&.display_name, amount_cell(record.cost) ]
      end
    end
  end

  # BigDecimal#to_s renders as "0.165e4", which spreadsheets read as text, so
  # every money cell is formatted to a plain fixed-point string.
  def amount_cell(value, precision: 2)
    return nil if value.nil?

    format("%.#{precision}f", value)
  end
end
