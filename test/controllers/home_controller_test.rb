require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "should get index" do
    get root_url
    assert_response :success
  end

  test "the dashboard warns when a settlement needs review" do
    users(:one).settlements.create!(
      truck: trucks(:one), statement_date: Date.current, statement_number: "FLAG",
      pay_deviation: "Line Haul Pay at 70.0% is below the agreed 76.0%"
    )

    get root_url

    assert_response :success
    assert_match "needs review", response.body
  end

  test "the dashboard stays quiet with clean settlements" do
    users(:one).settlements.create!(
      truck: trucks(:one), statement_date: Date.current, statement_number: "OK"
    )

    get root_url

    assert_response :success
    assert_no_match(/needs review/, response.body)
  end
end
