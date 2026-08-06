require "test_helper"

class TaxPaymentTest < ActiveSupport::TestCase
  test "the quarterly total is an exact BigDecimal" do
    user = users(:one)
    user.tax_payments.create!(payment_date: Date.new(2026, 9, 10), quarter: "Q3", amount: 100.10)
    user.tax_payments.create!(payment_date: Date.new(2026, 9, 12), quarter: "Q3", amount: 200.20)
    # Same quarter, wrong year: excluded.
    user.tax_payments.create!(payment_date: Date.new(2025, 9, 12), quarter: "Q3", amount: 999.99)

    total = TaxPayment.quarter_total(user.tax_payments, "Q3", 2026)

    # 100.10 + 200.20 is exactly 300.30 — the float sum lands on
    # 300.29999999999995 and only rounding hides it.
    assert_instance_of BigDecimal, total
    assert_equal 300.30.to_d, total
  end

  test "a quarter with no payments totals exactly zero" do
    assert_equal 0.to_d, TaxPayment.quarter_total(users(:one).tax_payments, "Q4", 2026)
  end
end
