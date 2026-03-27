require "test_helper"

class FuelLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @fuel_log = fuel_logs(:one)
  end

  test "should get index" do
    get fuel_logs_url
    assert_response :success
  end

  test "should get new" do
    get new_fuel_log_url
    assert_response :success
  end

  test "should create fuel_log" do
    assert_difference("FuelLog.count") do
      post fuel_logs_url, params: { fuel_log: { fuel_date: @fuel_log.fuel_date, gallons: @fuel_log.gallons, location: @fuel_log.location, notes: @fuel_log.notes, odometer: @fuel_log.odometer, price_per_gallon: @fuel_log.price_per_gallon, station: @fuel_log.station, total_cost: @fuel_log.total_cost } }
    end

    assert_redirected_to fuel_log_url(FuelLog.last)
  end

  test "should show fuel_log" do
    get fuel_log_url(@fuel_log)
    assert_response :success
  end

  test "should get edit" do
    get edit_fuel_log_url(@fuel_log)
    assert_response :success
  end

  test "should update fuel_log" do
    patch fuel_log_url(@fuel_log), params: { fuel_log: { fuel_date: @fuel_log.fuel_date, gallons: @fuel_log.gallons, location: @fuel_log.location, notes: @fuel_log.notes, odometer: @fuel_log.odometer, price_per_gallon: @fuel_log.price_per_gallon, station: @fuel_log.station, total_cost: @fuel_log.total_cost } }
    assert_redirected_to fuel_log_url(@fuel_log)
  end

  test "should destroy fuel_log" do
    assert_difference("FuelLog.count", -1) do
      delete fuel_log_url(@fuel_log)
    end

    assert_redirected_to fuel_logs_url
  end
end
