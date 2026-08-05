require "test_helper"

class SettlementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  def flagged_settlement!
    users(:one).settlements.create!(
      truck: trucks(:one), statement_date: Date.new(2026, 6, 1), statement_number: "FLAG",
      linehaul: 1_185.75, gross_linehaul: 1_395.00,
      pay_deviation: "Line Haul Pay at 85.0% is above the agreed 76.0%"
    )
  end

  def clean_settlement!
    users(:one).settlements.create!(
      truck: trucks(:one), statement_date: Date.new(2026, 6, 1), statement_number: "OK",
      linehaul: 1_976.00, gross_linehaul: 2_600.00
    )
  end

  test "the index warns when a settlement needs review" do
    flagged_settlement!

    get settlements_url(start_date: "2026-06-01", end_date: "2026-06-30")

    assert_response :success
    assert_match "needs review", response.body
    assert_match "above the agreed", response.body
  end

  test "the index stays quiet when nothing deviates" do
    clean_settlement!

    get settlements_url(start_date: "2026-06-01", end_date: "2026-06-30")

    assert_response :success
    assert_no_match(/needs review/, response.body)
  end

  test "the settlement page shows its deviation and lease findings" do
    settlement = flagged_settlement!
    users(:one).lease_terms.create!(kind: "deduction", label: "Bobtail Insurance", weekly_amount: 6.92)
    settlement.settlement_deductions.create!(label: "Mystery Fee", category: "other",
                                             scheduled_amount: 45.00, collected_this_statement: 45.00)

    get settlement_url(settlement)

    assert_response :success
    assert_match "above the agreed", response.body
    assert_match "Mystery Fee", response.body
    assert_match "not legal advice", response.body
  end

  test "a clean settlement page carries no warning box" do
    settlement = clean_settlement!

    get settlement_url(settlement)

    assert_response :success
    assert_no_match(/needs review/, response.body)
  end

  test "marking a settlement reviewed silences the warnings" do
    settlement = flagged_settlement!

    post review_settlement_url(settlement)
    assert_redirected_to settlement_url(settlement)

    get settlements_url(start_date: "2026-06-01", end_date: "2026-06-30")
    assert_no_match(/needs review/, response.body)

    get root_url
    assert_no_match(/needs review/, response.body)
  end

  test "a reviewed settlement page shows the acceptance instead of a warning" do
    settlement = flagged_settlement!
    post review_settlement_url(settlement)

    get settlement_url(settlement)

    assert_response :success
    assert_no_match(/needs review/, response.body)
    assert_match "Reviewed and accepted", response.body
    assert_match "above the agreed", response.body
    assert_match "Reopen review", response.body
  end

  test "reopening a review brings the warning back" do
    settlement = flagged_settlement!
    post review_settlement_url(settlement)
    delete review_settlement_url(settlement)

    get settlement_url(settlement)

    assert_response :success
    assert_match "needs review", response.body
    assert_match "Mark as reviewed", response.body
  end
end
