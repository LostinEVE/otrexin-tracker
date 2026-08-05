class SettlementsController < ApplicationController
  before_action :set_settlement, only: %i[ show destroy ]

  def index
    @start_date = parse_date(params[:start_date]) || Date.current.beginning_of_year
    @end_date = parse_date(params[:end_date]) || Date.current

    @settlements = current_user.settlements
      .includes(:truck, :expenses)
      .for_period(@start_date, @end_date)
    @settlements = @settlements.where(truck: selected_truck) if selected_truck
    @settlements = @settlements.order(statement_date: :desc)

    @summary = OperatingSummary.new(
      user: current_user,
      start_date: @start_date,
      end_date: @end_date,
      truck: selected_truck
    )

    @review_notes = settlement_review_notes(@settlements)
  end

  def show
    @review_notes = settlement_review_notes([ @settlement ]).fetch(@settlement.id, [])
  end

  def destroy
    date = @settlement.statement_date
    @settlement.destroy!

    redirect_to settlements_path,
                notice: "Deleted the #{date} settlement and the deductions it recorded.",
                status: :see_other
  end

  private

  def set_settlement
    @settlement = current_user.settlements.includes(:expenses).find(params.expect(:id))
  end

  def parse_date(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue Date::Error
    nil
  end
end
