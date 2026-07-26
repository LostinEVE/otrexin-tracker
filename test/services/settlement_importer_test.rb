require "test_helper"

class SettlementImporterTest < ActiveSupport::TestCase
  def result(name = "settlement_statement")
    SettlementStatementParser.new(file_fixture("#{name}.txt").read).parse
  end

  def importer
    SettlementImporter.new(user: users(:one), truck: trucks(:one))
  end

  test "a reconciling statement becomes a settlement and its deductions" do
    outcome = nil
    assert_difference [ "Settlement.count" ], 1 do
      assert_difference "Expense.count", 14 do
        outcome = importer.import(result, filename: "statement.pdf")
      end
    end

    assert outcome.imported?
    settlement = outcome.settlement
    assert_equal 2_846.00.to_d, settlement.truck_revenue
    assert_equal 1_013.19.to_d, settlement.total_deductions
    assert_equal 1_401.00.to_d, settlement.fuel_advance
    # Revenue less everything withheld, matching the statement balance.
    assert_equal 431.81.to_d, settlement.net_balance
  end

  test "the fuel advance is recorded but never expensed" do
    outcome = importer.import(result)

    fuel_expenses = outcome.settlement.expenses.where(category: "fuel")
    assert_empty fuel_expenses, "fuel receipts are entered separately; counting both would double it"
    assert_equal 1_401.00.to_d, outcome.settlement.fuel_advance
  end

  test "escrow lands in escrow and stays out of operating cost" do
    importer.import(result)
    summary = OperatingSummary.year(user: users(:one), year: 2026, truck: trucks(:one))

    # 50 contractor escrow plus 125 trailer escrow.
    assert_equal 175.00.to_d, summary.escrow_total
    assert_equal 838.19.to_d, summary.expense_total - 1_100.to_d
  end

  test "a statement that does not reconcile is refused outright" do
    broken = result
    broken.total_deductions = 9_999.99.to_d

    outcome = nil
    assert_no_difference [ "Settlement.count", "Expense.count" ] do
      outcome = importer.import(broken)
    end

    assert outcome.failed?
    assert_includes outcome.message, "off by"
  end

  test "importing the same statement twice is harmless" do
    first = importer.import(result)
    second = nil

    assert_no_difference [ "Settlement.count", "Expense.count" ] do
      second = importer.import(result)
    end

    assert first.imported?
    assert second.skipped?
    assert_equal first.settlement, second.settlement
  end

  test "a statement with no date is refused" do
    empty = SettlementStatementParser.new("nothing useful here").parse

    assert_no_difference "Settlement.count" do
      assert importer.import(empty).failed?
    end
  end

  test "paid miles are kept on the settlement" do
    outcome = importer.import(result)

    assert_includes outcome.settlement.notes, "1,377"
  end

  # Guards the case that would quietly double a driver's books: the same
  # settlement already typed in by hand.
  test "a statement already entered by hand is held back rather than doubled" do
    [ 33.46, 125.00, 175.00, 50.00 ].each_with_index do |amount, index|
      Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                      category: "insurance", vendor: "Kaplan", amount: amount, notes: "typed by hand #{index}")
    end

    outcome = nil
    assert_no_difference [ "Settlement.count", "Expense.count" ] do
      outcome = importer.import(result)
    end

    assert outcome.conflict?
    assert_includes outcome.message, "entered by hand"
    assert_operator outcome.conflicts.size, :>=, 3
  end

  test "a date typed up a day late is still recognised as the same settlement" do
    [ 33.46, 125.00, 175.00, 50.00 ].each do |amount|
      Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 15),
                      category: "insurance", vendor: "Kaplan", amount: amount)
    end

    assert importer.import(result).conflict?
  end

  test "replacing removes the hand-typed rows and records the statement instead" do
    4.times do |index|
      Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                      category: "insurance", vendor: "Kaplan", amount: [ 33.46, 125.00, 175.00, 50.00 ][index])
    end

    outcome = importer.import(result, replace_existing: true)

    assert outcome.imported?
    assert_includes outcome.message, "Replaced 4 hand-entered rows"
    assert_equal 14, outcome.settlement.expenses.count
    # Nothing hand-typed survives on that date to be counted a second time.
    assert_empty Expense.where(settlement_id: nil, expense_date: Date.new(2026, 7, 14))
  end

  test "unrelated expenses on the same date are not mistaken for the settlement" do
    Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                    category: "fuel", vendor: "Pilot", amount: 812.44)

    assert importer.import(result).imported?
  end

  test "expenses already tied to a settlement are never treated as a conflict" do
    first = importer.import(result)
    assert first.imported?

    # A second statement on the same dates sees fourteen matching amounts, but
    # they all belong to a settlement already, so they are not hand-typed rows.
    second = result
    second.statement_number = "OTHER"
    assert_not importer.import(second).conflict?
  end
end
