require "test_helper"

# Fixtures are anonymised statements laid out exactly as the PDF reader produces
# them. Real settlements are financial documents and do not belong in a repo, so
# the parsing half is tested on text and the extraction half is left to the gem.
class SettlementStatementParserTest < ActiveSupport::TestCase
  def parse(name)
    SettlementStatementParser.new(file_fixture("#{name}.txt").read).parse
  end

  test "reads the statement header" do
    result = parse("settlement_statement")

    assert_equal Date.new(2026, 7, 14), result.statement_date
    assert_equal "00999001", result.statement_number
    assert_equal 1, result.load_count
    assert_equal 1_377, result.miles
  end

  test "revenue is what reached the truck, not what the customer was billed" do
    result = parse("settlement_statement")

    assert_equal 1_976.00.to_d, result.linehaul
    assert_equal 870.00.to_d, result.fuel_surcharge
    assert_equal 2_846.00.to_d, result.truck_revenue
    assert_equal 2_600.00.to_d, result.gross_linehaul
  end

  test "every deduction on the statement is found" do
    result = parse("settlement_statement")

    assert_equal 14, result.deductions.size
    assert_equal 1_013.19.to_d, result.deduction_sum
  end

  # The whole point of the reader: it proves itself against the figure the
  # statement prints rather than asking to be trusted.
  test "the total it finds matches the total the statement states" do
    result = parse("settlement_statement")

    assert_equal 1_401.00.to_d, result.fuel_advance
    assert_equal 2_414.19.to_d, result.total_deductions
    assert_equal 2_414.19.to_d, result.accounted_for
    assert result.reconciled?
    assert_equal 0.to_d, result.discrepancy
  end

  test "deduction labels are mapped onto expense categories" do
    by_label = parse("settlement_statement").deductions.index_by { |line| line[:label] }

    assert_equal "escrow", by_label["Contractor Escrow"][:category]
    assert_equal "escrow", by_label["SSI Trailer Escrow"][:category]
    assert_equal "trailer_lease", by_label["SSI Trailer Lease Purchase"][:category]
    assert_equal "loan_payment", by_label["Loan"][:category]
    assert_equal "loan_payment", by_label["Loan Fee"][:category]
    assert_equal "eld_dashcam", by_label["Dash Cam"][:category]
    assert_equal "eld_dashcam", by_label["E-Log"][:category]
    assert_equal "insurance", by_label["Bobtail Insurance"][:category]
    assert_equal "insurance", by_label["Occupational Accident Insurance"][:category]
    assert_equal "permits", by_label["Plates"][:category]
    assert by_label.values.all? { |line| Expense::CATEGORIES.key?(line[:category]) }
  end

  test "payoff totals are read where the carrier prints them" do
    by_label = parse("settlement_statement").deductions.index_by { |line| line[:label] }

    loan = by_label["Loan"]
    assert_equal 1_219.31.to_d, loan[:balance_target]
    assert_equal 300.00.to_d, loan[:weekly]

    # A flat weekly line has no payoff total, so the single figure is the amount.
    bobtail = by_label["Bobtail Insurance"]
    assert_nil bobtail[:balance_target]
    assert_equal 6.92.to_d, bobtail[:weekly]
  end

  test "the amortization sub-table is read in full" do
    deductions = parse("settlement_statement").deductions

    # Total: ($130.00) ($130.00) ($910.00) ($1,040.00) ($260.00)
    permits = deductions.find { |line| line[:label] == "Permits Driver" }
    assert_equal 130.00.to_d, permits[:scheduled_amount]
    assert_equal 130.00.to_d, permits[:amount]
    assert_equal 0.to_d, permits[:uncollected]
    assert_equal 910.00.to_d, permits[:previous_collected]
    assert_equal 1_040.00.to_d, permits[:total_collected_to_date]
    assert_equal 260.00.to_d, permits[:new_balance]

    # Total: ($300.00) ($300.00) ($600.00) ($900.00) ($319.31)
    loan = deductions.find { |line| line[:label] == "Loan" }
    assert_equal 300.00.to_d, loan[:scheduled_amount]
    assert_equal 600.00.to_d, loan[:previous_collected]
    assert_equal 900.00.to_d, loan[:total_collected_to_date]
    assert_equal 319.31.to_d, loan[:new_balance]
  end

  test "a payoff that reached its target on this statement reads as finished" do
    # Plates - ($476.00) @ ($75.00)/Week: $450.00 previously collected plus a
    # final $26.00 this statement reaches the $476.00 target. The statement
    # prints no New Balance figure on that Total row, which means zero.
    plates = parse("settlement_statement").deductions
      .find { |line| line[:label] == "Plates" && line[:balance_target] == 476.00.to_d }

    assert_equal 26.00.to_d, plates[:scheduled_amount]
    assert_equal 26.00.to_d, plates[:amount]
    assert_equal 450.00.to_d, plates[:previous_collected]
    assert_equal 476.00.to_d, plates[:total_collected_to_date]
    assert_equal 0.to_d, plates[:new_balance]
  end

  test "a flat weekly line carries no balance at all" do
    # Total: ($6.92) ($6.92) — no running totals, no balance, nothing to pay off.
    bobtail = parse("settlement_statement").deductions
      .find { |line| line[:label] == "Bobtail Insurance" }

    assert_equal 6.92.to_d, bobtail[:scheduled_amount]
    assert_equal 6.92.to_d, bobtail[:amount]
    assert_nil bobtail[:new_balance]
  end

  test "a permit charged against the load is picked up" do
    result = parse("settlement_with_trip_permit")

    permit = result.deductions.find { |line| line[:label] == "Trip Permit" }
    assert permit, "a trip permit is a real cost that appears nowhere else"
    assert_equal 23.80.to_d, permit[:amount]
    assert_equal "permits", permit[:category]
    assert_includes permit[:detail], "Commodity"
    assert result.reconciled?
  end

  test "an unreadable statement reports itself rather than parsing to zero" do
    result = SettlementStatementParser.new("this is not a settlement statement").parse

    assert_not result.reconciled?
    assert result.errors.any?
  end
end
