class ReportsController < ApplicationController
  def profit_loss
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current.beginning_of_year
    @end_date   = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current

    paid_invoices = current_user.invoices.where(status: "paid", invoice_date: @start_date..@end_date)
    expense_rows = current_user.expenses.where(expense_date: @start_date..@end_date)
    maintenance_rows = current_user.maintenances.where(maintenance_date: @start_date..@end_date)
    mileage_rows = current_user.mileages.where(trip_date: @start_date..@end_date)

    @revenue_total = paid_invoices.sum(:amount).to_f
    @expense_total = expense_rows.sum(:amount).to_f
    @maintenance_total = maintenance_rows.sum(:cost).to_f
    @operating_cost_total = @expense_total + @maintenance_total
    @net_profit = @revenue_total - @operating_cost_total

    @expense_by_category = expense_rows.group(:category).sum(:amount).sort_by { |_k, v| -v.to_f }

    miles = mileage_rows.sum(:miles).to_f
    @revenue_per_mile = miles.positive? ? (@revenue_total / miles).round(4) : nil
    @cost_per_mile = miles.positive? ? (@operating_cost_total / miles).round(4) : nil

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
  rescue ArgumentError
    redirect_to reports_profit_loss_path, alert: "Invalid date range."
  end

  private

  def build_profit_loss_csv
    CSV.generate(headers: true) do |csv|
      csv << ["OTR Tracker Profit & Loss"]
      csv << ["Period", "#{@start_date} to #{@end_date}"]
      csv << []
      csv << ["Summary", "Amount"]
      csv << ["Revenue", @revenue_total.round(2)]
      csv << ["Expenses", @expense_total.round(2)]
      csv << ["Maintenance", @maintenance_total.round(2)]
      csv << ["Operating Cost Total", @operating_cost_total.round(2)]
      csv << ["Net Profit", @net_profit.round(2)]
      csv << ["Revenue per Mile", @revenue_per_mile]
      csv << ["Cost per Mile", @cost_per_mile]
      csv << []
      csv << ["Expense Category", "Amount"]
      @expense_by_category.each do |category, amount|
        csv << [category, amount.to_f.round(2)]
      end
    end
  end
end
