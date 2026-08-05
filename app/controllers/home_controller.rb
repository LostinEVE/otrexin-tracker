class HomeController < ApplicationController
  def index
    today = Date.current
    truck = selected_truck

    @month = OperatingSummary.new(
      user: current_user,
      start_date: today.beginning_of_month,
      end_date: today,
      truck: truck
    )

    # Performance metrics are year-to-date so they sit on the same footing as the
    # revenue and expense cards beside them, instead of mixing a lifetime figure
    # into a row of period figures.
    @year = OperatingSummary.new(
      user: current_user,
      start_date: today.beginning_of_year,
      end_date: today,
      truck: truck
    )

    invoice_scope = current_user.invoices
    invoice_scope = invoice_scope.where(truck: truck) if truck

    @unpaid_total = invoice_scope.where(status: "unpaid").sum(:amount)
    @recent_unpaid = invoice_scope.where(status: "unpaid").order(invoice_date: :desc).limit(5)

    @overall_mpg = FuelLog.overall_mpg(@year.fuel_logs)

    review_scope = current_user.settlements
    review_scope = review_scope.where(truck: truck) if truck
    @review_notes = settlement_review_notes(review_scope)
  end
end
