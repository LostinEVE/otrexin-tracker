require "test_helper"

# Every page a signed-in driver can reach, rendered for real. Model tests do not
# catch a view that references a renamed constant or a helper that is not there,
# and several of these pages have no controller test of their own.
class PageSmokeTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  def assert_renders(url)
    get url
    assert_response :success, "GET #{url} did not render"
  end

  test "dashboard and reports render" do
    assert_renders root_url
    assert_renders root_url(truck_id: trucks(:one).id)
    assert_renders reports_profit_loss_url
    assert_renders reports_profit_loss_url(truck_id: trucks(:one).id)
  end

  test "expense pages render" do
    assert_renders expenses_url
    assert_renders new_expense_url
    assert_renders expense_url(expenses(:one))
    assert_renders edit_expense_url(expenses(:one))
  end

  test "the prefilled expense form carries the reconciliation hand off" do
    log = fuel_logs(:one)

    get new_expense_url(
      truck_id: log.truck_id,
      category: "fuel",
      amount: log.total_cost,
      expense_date: log.fuel_date,
      vendor: "Pilot"
    )

    assert_response :success
    expense = @controller.view_assigns["expense"]
    assert_equal "fuel", expense.category
    assert_equal log.total_cost, expense.amount
    assert_equal log.fuel_date, expense.expense_date
    assert_equal log.truck_id, expense.truck_id
  end

  test "a prefilled truck the user does not own is refused" do
    get new_expense_url(truck_id: trucks(:three).id, category: "fuel")

    assert_response :success
    expense = @controller.view_assigns["expense"]
    assert_not_equal trucks(:three).id, expense.truck_id
  end

  test "fuel and maintenance pages render" do
    assert_renders fuel_logs_url
    assert_renders new_fuel_log_url
    assert_renders fuel_log_url(fuel_logs(:one))
    assert_renders edit_fuel_log_url(fuel_logs(:one))
    assert_renders maintenances_url
    assert_renders new_maintenance_url
    assert_renders maintenance_url(maintenances(:one))
    assert_renders edit_maintenance_url(maintenances(:one))
  end

  test "truck pages render" do
    assert_renders trucks_url
    assert_renders new_truck_url
    assert_renders edit_truck_url(trucks(:one))
  end

  test "tax pages render" do
    assert_renders tax_payments_url
    assert_renders per_diem_entries_url
    assert_renders new_per_diem_entry_url
    assert_renders depreciation_assets_url
    assert_renders new_depreciation_asset_url
  end

  test "invoice and company pages render" do
    assert_renders invoices_url
    assert_renders new_invoice_url
    assert_renders invoice_url(invoices(:one))
    assert_renders edit_invoice_url(invoices(:one))
    assert_renders customers_url
    assert_renders company_profile_url
    assert_renders edit_company_profile_url
  end

  test "csv exports render" do
    assert_renders expenses_url(format: :csv)
    assert_renders maintenances_url(format: :csv)
    assert_renders reports_profit_loss_url(format: :csv)
  end

  test "a truck's starting odometer can be saved from the form" do
    patch truck_url(trucks(:one)), params: { truck: { name: trucks(:one).name, baseline_odometer: 950 } }

    assert_response :redirect
    assert_equal 950, trucks(:one).reload.baseline_odometer
  end
end
