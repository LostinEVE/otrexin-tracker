require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "should get profit_loss" do
    get reports_profit_loss_url
    assert_response :success
  end

  test "shows expenses as the operating cost without adding the maintenance log" do
    get reports_profit_loss_url(start_date: "2026-01-01", end_date: "2026-12-31")

    assert_response :success
    assert_equal 1_650.to_d, summary.expense_total
    assert_equal 3_350.to_d, summary.net_profit
  end

  test "reports cost per mile from fuel derived miles" do
    get reports_profit_loss_url(start_date: "2026-01-01", end_date: "2026-12-31")

    assert_equal 500, summary.total_miles
    assert_equal 3.3.to_d, summary.cost_per_mile
  end

  test "scopes the statement to the selected truck" do
    get reports_profit_loss_url(truck_id: trucks(:one).id, start_date: "2026-01-01", end_date: "2026-12-31")

    assert_equal 1_100.to_d, summary.expense_total
  end

  test "cannot report on another user's truck" do
    get reports_profit_loss_url(truck_id: trucks(:three).id, start_date: "2026-01-01", end_date: "2026-12-31")

    assert_response :success
    # An unowned truck id is ignored rather than honoured, so the report falls
    # back to this user's own records instead of exposing anything.
    assert_equal 1_650.to_d, summary.expense_total
  end

  test "does not nag when expenses already cover the logged costs" do
    get reports_profit_loss_url(start_date: "2026-01-01", end_date: "2026-12-31")

    assert_response :success
    assert summary.reconciled?
    assert_select "h2", text: "Needs Reconciling", count: 0
  end

  test "lists logged costs that no expense accounts for" do
    get reports_profit_loss_url(truck_id: trucks(:one).id, start_date: "2026-01-01", end_date: "2026-12-31")

    assert_response :success
    assert_not summary.reconciled?
    assert_equal 400.to_d, summary.unreconciled_total
    assert_select "h2", text: "Needs Reconciling"
  end

  test "rejects a backwards date range" do
    get reports_profit_loss_url(start_date: "2026-12-31", end_date: "2026-01-01")

    assert_redirected_to reports_profit_loss_path
    assert_equal "End date must be on or after the start date.", flash[:alert]
  end

  test "rejects an unparseable date" do
    get reports_profit_loss_url(start_date: "not-a-date")

    assert_redirected_to reports_profit_loss_path
    assert_equal "Invalid date range.", flash[:alert]
  end

  test "exports the statement as csv without scientific notation" do
    get reports_profit_loss_url(format: :csv, start_date: "2026-01-01", end_date: "2026-12-31")

    assert_response :success
    assert_equal "text/csv", response.media_type

    rows = CSV.parse(response.body)
    assert_includes rows, [ "Operating Expenses", "1650.00" ]
    assert_includes rows, [ "Total Miles (from fuel odometer)", "500" ]
    assert_includes rows, [ "Cost per Mile", "3.300" ]
  end

  private

  def summary
    @controller.view_assigns["summary"]
  end
end
