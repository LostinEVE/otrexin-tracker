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

    # 1377 as printed on the statement's load line, not prose in notes.
    assert_equal 1_377, outcome.settlement.miles
    assert_nil outcome.settlement.notes
  end

  test "the statement's amortization detail is kept per deduction" do
    outcome = importer.import(result)
    details = outcome.settlement.settlement_deductions

    assert_equal 14, details.count

    loan = details.find_by(label: "Loan")
    assert_equal 300.00.to_d, loan.scheduled_amount
    assert_equal 300.00.to_d, loan.collected_this_statement
    assert_equal 600.00.to_d, loan.previous_collected
    assert_equal 900.00.to_d, loan.total_collected_to_date
    assert_equal 319.31.to_d, loan.new_balance
    assert_equal 300.00.to_d, loan.weekly_amount
    assert_equal 1_219.31.to_d, loan.balance_target
    assert_not loan.finished?

    # The single most valuable fact on the statement: a recurring deduction
    # that just ended. $450.00 + $26.00 reached the $476.00 target.
    finished = details.find_by(balance_target: 476.00.to_d)
    assert_equal "Plates", finished.label
    assert_equal 0.to_d, finished.new_balance
    assert finished.finished?
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

    outcome = importer.import(result, on_conflict: :replace)

    assert outcome.imported?
    assert_includes outcome.message, "4 hand-entered rows replaced"
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

  # The option that matters most to a driver who has been typing settlements in:
  # keep the work already done, add only what is missing, double nothing.
  test "merging adopts the rows already typed instead of adding a second copy" do
    typed = [ 33.46, 125.00, 175.00, 50.00 ].map do |amount|
      Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                      category: "other", vendor: "Kaplan", amount: amount, notes: "my note #{amount}")
    end

    outcome = nil
    # Fourteen deductions, four of which already exist, so only ten are new.
    assert_difference "Expense.count", 10 do
      outcome = importer.import(result, on_conflict: :merge)
    end

    assert outcome.imported?
    assert_equal 14, outcome.settlement.expenses.count
    assert typed.all? { |expense| expense.reload.settlement == outcome.settlement }
  end

  test "merging records the revenue that holding leaves behind" do
    4.times { |i| Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                                  category: "other", vendor: "Kaplan", amount: [ 33.46, 125.00, 175.00, 50.00 ][i]) }

    outcome = importer.import(result, on_conflict: :merge)

    assert_equal 2_846.00.to_d, outcome.settlement.truck_revenue
    assert_includes outcome.message, "matched to what you already entered"
  end

  test "merging corrects the category of an adopted row from the statement" do
    escrow = Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                             category: "other", vendor: "Kaplan", amount: 125.00, notes: "Trailer escrow")
    3.times { |i| Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                                  category: "other", vendor: "Kaplan", amount: [ 33.46, 175.00, 50.00 ][i]) }

    importer.import(result, on_conflict: :merge)

    # Filed under Other by hand, it belongs in escrow — and therefore out of
    # operating cost entirely.
    assert_equal "escrow", escrow.reload.category
  end

  test "merging keeps the driver's own note" do
    typed = Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                            category: "other", vendor: "Kaplan", amount: 130.00, notes: "Ky permit Bal(260.00)")
    3.times { |i| Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                                  category: "other", vendor: "Kaplan", amount: [ 33.46, 175.00, 50.00 ][i]) }

    importer.import(result, on_conflict: :merge)

    assert_equal "Ky permit Bal(260.00)", typed.reload.notes
  end

  test "merging does not count the same money twice" do
    4.times { |i| Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                                  category: "other", vendor: "Kaplan", amount: [ 33.46, 125.00, 175.00, 50.00 ][i]) }

    outcome = importer.import(result, on_conflict: :merge)

    # Deductions on the books for that day equal the statement's own total, not
    # the total plus the four rows that were already there.
    recorded = Expense.where(expense_date: Date.new(2026, 7, 14)).sum(:amount)
    assert_equal outcome.settlement.total_deductions, recorded
    assert_equal 1_013.19.to_d, recorded
  end

  test "an unknown strategy falls back to holding rather than writing" do
    4.times { |i| Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                                  category: "other", vendor: "Kaplan", amount: [ 33.46, 125.00, 175.00, 50.00 ][i]) }

    assert_no_difference "Settlement.count" do
      assert importer.import(result, on_conflict: :something_else).conflict?
    end
  end
end
