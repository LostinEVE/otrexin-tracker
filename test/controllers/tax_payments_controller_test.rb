require "test_helper"

class TaxPaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tax_payment = tax_payments(:one)
  end

  test "should get index" do
    get tax_payments_url
    assert_response :success
  end

  test "should get new" do
    get new_tax_payment_url
    assert_response :success
  end

  test "should create tax_payment" do
    assert_difference("TaxPayment.count") do
      post tax_payments_url, params: { tax_payment: { amount: @tax_payment.amount, notes: @tax_payment.notes, payment_date: @tax_payment.payment_date, quarter: @tax_payment.quarter } }
    end

    assert_redirected_to tax_payment_url(TaxPayment.last)
  end

  test "should show tax_payment" do
    get tax_payment_url(@tax_payment)
    assert_response :success
  end

  test "should get edit" do
    get edit_tax_payment_url(@tax_payment)
    assert_response :success
  end

  test "should update tax_payment" do
    patch tax_payment_url(@tax_payment), params: { tax_payment: { amount: @tax_payment.amount, notes: @tax_payment.notes, payment_date: @tax_payment.payment_date, quarter: @tax_payment.quarter } }
    assert_redirected_to tax_payment_url(@tax_payment)
  end

  test "should destroy tax_payment" do
    assert_difference("TaxPayment.count", -1) do
      delete tax_payment_url(@tax_payment)
    end

    assert_redirected_to tax_payments_url
  end
end
