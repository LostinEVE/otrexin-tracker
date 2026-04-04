require "test_helper"

class MileagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @mileage = mileages(:one)
  end

  test "should get index" do
    get mileages_url
    assert_response :success
  end

  test "should get new" do
    get new_mileage_url
    assert_response :success
  end

  test "should create mileage" do
    assert_difference("Mileage.count") do
      post mileages_url, params: { mileage: { destination: @mileage.destination, load_number: @mileage.load_number, miles: @mileage.miles, notes: @mileage.notes, origin: @mileage.origin, revenue: @mileage.revenue, trip_date: @mileage.trip_date } }
    end

    assert_redirected_to mileage_url(Mileage.last)
  end

  test "should show mileage" do
    get mileage_url(@mileage)
    assert_response :success
  end

  test "should get edit" do
    get edit_mileage_url(@mileage)
    assert_response :success
  end

  test "should update mileage" do
    patch mileage_url(@mileage), params: { mileage: { destination: @mileage.destination, load_number: @mileage.load_number, miles: @mileage.miles, notes: @mileage.notes, origin: @mileage.origin, revenue: @mileage.revenue, trip_date: @mileage.trip_date } }
    assert_redirected_to mileage_url(@mileage)
  end

  test "should destroy mileage" do
    assert_difference("Mileage.count", -1) do
      delete mileage_url(@mileage)
    end

    assert_redirected_to mileages_url
  end
end
