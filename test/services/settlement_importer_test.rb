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
    # Fourteen deduction lines: twelve are costs and become expenses, two are
    # escrow deposits and go to the ledger instead.
    assert_difference [ "Settlement.count" ], 1 do
      assert_difference [ "Expense.count" ], 12 do
        assert_difference [ "EscrowLedgerEntry.count" ], 2 do
          outcome = importer.import(result, filename: "statement.pdf")
        end
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

  test "escrow lines become ledger entries carrying the statement's own figures" do
    outcome = importer.import(result)

    # Contractor Escrow Total row: ($50.00) ($50.00) ($350.00) ($400.00) ($100.00)
    contractor = outcome.settlement.escrow_ledger_entries.find_by(name: "Contractor Escrow")
    assert_equal 50.00.to_d, contractor.deposit_amount
    assert_equal 400.00.to_d, contractor.running_balance
    assert_equal 500.00.to_d, contractor.target

    # SSI Trailer Escrow Total row: ($125.00) ($125.00) ($125.00) ($250.00) ($1,750.00)
    trailer = outcome.settlement.escrow_ledger_entries.find_by(name: "SSI Trailer Escrow")
    assert_equal 125.00.to_d, trailer.deposit_amount
    assert_equal 250.00.to_d, trailer.running_balance
    assert_equal 2_000.00.to_d, trailer.target

    assert_empty outcome.settlement.expenses.where(category: "escrow")
  end

  test "escrow and the fuel advance stay out of every operating aggregate" do
    importer.import(result)
    summary = OperatingSummary.year(user: users(:one), year: 2026, truck: trucks(:one))
    estimator = TaxEstimator.new(user: users(:one), year: 2026, truck: trucks(:one))

    # 838.19 of operating deductions plus the 1,100.00 of seeded fixture
    # expenses. Not the 175.00 of escrow, and not the 1,401.00 fuel advance —
    # one is a refundable deposit, the other is repayment of borrowed money.
    assert_equal 1_938.19.to_d, summary.expense_total
    assert_equal 1_938.19.to_d, estimator.operating_expenses
    assert_equal 175.00.to_d, summary.escrow_total
    assert_equal 175.00.to_d, summary.escrow_balance
  end

  test "a statement that does not reconcile is refused outright" do
    broken = result
    broken.collected_deductions = 9_999.99.to_d

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

  test "accessorial lines become rows carrying their stated rates" do
    outcome = importer.import(result("settlement_with_accessorials"))

    rows = outcome.settlement.settlement_accessorials
    assert_equal 2, rows.count

    layover = rows.find_by(label: "Driver Layover Expen")
    assert_equal 750.00.to_d, layover.gross_amount
    assert_equal 100.to_d, layover.percentage_applied
    assert_equal 750.00.to_d, layover.net_amount

    stop_off = rows.find_by(label: "Stop Off")
    assert_equal 300.00.to_d, stop_off.gross_amount
    assert_equal 76.to_d, stop_off.percentage_applied
    assert_equal 228.00.to_d, stop_off.net_amount
  end

  test "realized rates are stored and a clean statement carries no deviation" do
    outcome = importer.import(result("settlement_with_accessorials"))

    assert_equal 0.76.to_d, outcome.settlement.realized_linehaul_rate
    assert_equal 1.to_d, outcome.settlement.realized_fuel_surcharge_rate
    assert_nil outcome.settlement.pay_deviation
  end

  test "a pay line that shorts the stated rate is flagged at import" do
    # 76% of $300.00 is $228.00; a statement printing $200.00 is short $28.00.
    doctored = SettlementStatementParser.new(<<~TEXT).parse
      SETTLEMENT STATEMENT 07/31/2026
      Stop Off                                       $300.00         76 %          $200.00
    TEXT

    assert_includes doctored.pay_line_problems.join, "Stop Off"
  end

  test "an uncollected shortfall imports and stays queryable" do
    outcome = importer.import(result("settlement_with_uncollected"))

    assert outcome.imported?
    lease = outcome.settlement.settlement_deductions.find_by(label: "SSI Trailer Lease Purchase")
    assert_equal 55.13.to_d, lease.collected_this_statement
    assert_equal 244.87.to_d, lease.uncollected
    # Only collected money reaches the books: 32.31 + 55.13 + 20.00.
    assert_equal 107.44.to_d, outcome.settlement.total_deductions
    # Revenue 1,223.22 less 107.44 collected and the 461.00 fuel advance.
    assert_equal 654.78.to_d, outcome.settlement.net_balance
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
    assert_equal 12, outcome.settlement.expenses.count
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
    # Twelve deduction lines are costs; two of them (33.46 and 175.00) are
    # already typed and get adopted, so ten expenses are new. The 125.00 and
    # 50.00 rows match escrow lines: their money moves into the ledger and the
    # hand-typed expense rows go with it, so the net change is eight.
    assert_difference "Expense.count", 8 do
      outcome = importer.import(result, on_conflict: :merge)
    end

    assert outcome.imported?
    assert_equal 12, outcome.settlement.expenses.count
    assert_equal outcome.settlement, typed[0].reload.settlement # 33.46 adopted
    assert_equal outcome.settlement, typed[2].reload.settlement # 175.00 adopted
    # The escrow rows are not expenses any more; their money is in the ledger.
    assert_not Expense.exists?(typed[1].id)
    assert_not Expense.exists?(typed[3].id)
  end

  test "merging records the revenue that holding leaves behind" do
    4.times { |i| Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                                  category: "other", vendor: "Kaplan", amount: [ 33.46, 125.00, 175.00, 50.00 ][i]) }

    outcome = importer.import(result, on_conflict: :merge)

    assert_equal 2_846.00.to_d, outcome.settlement.truck_revenue
    assert_includes outcome.message, "matched to what you already entered"
  end

  test "merging moves a hand-typed escrow row into the ledger, note and all" do
    escrow = Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                             category: "other", vendor: "Kaplan", amount: 125.00, notes: "Trailer escrow")
    3.times { |i| Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                                  category: "other", vendor: "Kaplan", amount: [ 33.46, 175.00, 50.00 ][i]) }

    importer.import(result, on_conflict: :merge)

    # Filed under Other by hand, but it is a refundable deposit: it belongs in
    # the escrow ledger, out of expenses entirely, with the driver's note kept.
    assert_not Expense.exists?(escrow.id)
    entry = EscrowLedgerEntry.find_by(name: "SSI Trailer Escrow")
    assert_equal 125.00.to_d, entry.deposit_amount
    assert_includes entry.notes, "Trailer escrow"
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

    # Deductions on the books for that day equal the statement's own total —
    # 838.19 of costs in expenses plus 175.00 of escrow in the ledger — not
    # the total plus the four rows that were already there.
    recorded = Expense.where(expense_date: Date.new(2026, 7, 14)).sum(:amount)
    assert_equal 838.19.to_d, recorded
    assert_equal 1_013.19.to_d, outcome.settlement.total_deductions
  end

  test "an unknown strategy falls back to holding rather than writing" do
    4.times { |i| Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 7, 14),
                                  category: "other", vendor: "Kaplan", amount: [ 33.46, 125.00, 175.00, 50.00 ][i]) }

    assert_no_difference "Settlement.count" do
      assert importer.import(result, on_conflict: :something_else).conflict?
    end
  end
end
