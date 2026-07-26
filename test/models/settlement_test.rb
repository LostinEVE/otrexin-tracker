require "test_helper"

class SettlementTest < ActiveSupport::TestCase
  # Figures taken from a real Kaplan statement dated 07/14/2026.
  def kaplan_statement
    Settlement.create!(
      user: users(:one),
      truck: trucks(:one),
      statement_date: Date.new(2026, 7, 14),
      payer: "Kaplan",
      load_count: 1,
      gross_linehaul: 2_600.00,
      linehaul: 1_976.00,
      fuel_surcharge: 870.00,
      accessorials: 0.00
    )
  end

  test "truck revenue is what reached the driver, not what the customer was billed" do
    settlement = kaplan_statement

    assert_equal 2_846.00.to_d, settlement.truck_revenue
    assert_equal 76.0, settlement.linehaul_percentage
  end

  test "the settlement balance is revenue less every deduction it recorded" do
    settlement = kaplan_statement
    # The contractor-side deductions from that statement.
    {
      "Contractor Escrow" => [ 50.00, "escrow" ],
      "Equipment Loan" => [ 300.00, "loan_payment" ],
      "Loan Fee" => [ 30.00, "loan_payment" ],
      "Trailer Escrow" => [ 125.00, "escrow" ],
      "Trailer Lease Purchase" => [ 175.00, "trailer_lease" ],
      "Occupational Accident Insurance" => [ 33.46, "insurance" ],
      "Trailer Physical Damage" => [ 15.00, "insurance" ]
    }.each do |label, (amount, category)|
      Expense.create!(user: users(:one), truck: trucks(:one), settlement: settlement,
                      expense_date: settlement.statement_date, category: category,
                      amount: amount, notes: label)
    end

    assert_equal 728.46.to_d, settlement.total_deductions
    assert_equal 2_117.54.to_d, settlement.net_balance
  end

  test "deleting a settlement removes the deductions it created" do
    settlement = kaplan_statement
    Expense.create!(user: users(:one), truck: trucks(:one), settlement: settlement,
                    expense_date: settlement.statement_date, category: "insurance", amount: 33.46)

    assert_difference "Expense.count", -1 do
      settlement.destroy!
    end
  end

  test "gross linehaul never counts as income" do
    settlement = kaplan_statement
    summary = OperatingSummary.year(user: users(:one), year: 2026, truck: trucks(:one))

    # 2,600 was billed to the customer; only the 2,846 that reached the truck
    # (settlement plus surcharge) is revenue.
    assert_equal 2_846.00.to_d, summary.settlement_revenue
    assert_not_equal settlement.gross_linehaul, summary.settlement_revenue
  end

  test "settlement revenue and invoice revenue are both counted and kept distinct" do
    kaplan_statement
    summary = OperatingSummary.year(user: users(:one), year: 2026, truck: trucks(:one))

    assert_equal 5_000.to_d, summary.invoice_revenue
    assert_equal 2_846.00.to_d, summary.settlement_revenue
    assert_equal 7_846.00.to_d, summary.revenue
  end

  test "fuel surcharge offsets the cost of diesel" do
    kaplan_statement
    summary = OperatingSummary.year(user: users(:one), year: 2026, truck: trucks(:one))

    # Fixture truck one has an 800 fuel expense against 870 of surcharge.
    assert_equal 870.00.to_d, summary.fuel_surcharge_total
    assert_equal 800.to_d, summary.fuel_expense_total
    assert_equal(-70.00.to_d, summary.net_fuel_cost)
  end
end
