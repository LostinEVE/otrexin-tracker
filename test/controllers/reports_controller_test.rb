require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  test "should get profit_loss" do
    get reports_profit_loss_url
    assert_response :success
  end
end
