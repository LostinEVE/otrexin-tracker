require "test_helper"

class EscrowExpenseMigratorTest < ActiveSupport::TestCase
  def legacy_escrow!(amount, date, notes)
    Expense.create!(user: users(:one), truck: trucks(:one), expense_date: date,
                    category: "escrow", vendor: "Kaplan", amount: amount, notes: notes)
  end

  test "a dry run reports what would move and moves nothing" do
    legacy_escrow!(50.00, Date.new(2026, 5, 1), "Contractor Escrow")
    legacy_escrow!(125.00, Date.new(2026, 5, 1), "SSI Trailer Escrow")

    report = nil
    assert_no_difference [ "Expense.count", "EscrowLedgerEntry.count" ] do
      report = EscrowExpenseMigrator.call
    end

    assert_equal 2, report.rows
    assert_equal 175.00.to_d, report.total
    assert_not report.applied
  end

  test "applying moves each row into the ledger with a cumulative balance" do
    legacy_escrow!(50.00, Date.new(2026, 5, 1), "Contractor Escrow")
    legacy_escrow!(50.00, Date.new(2026, 5, 8), "Contractor Escrow — weekly")
    legacy_escrow!(125.00, Date.new(2026, 5, 8), "SSI Trailer Escrow")

    assert_difference "EscrowLedgerEntry.count", 3 do
      assert_difference "Expense.count", -3 do
        EscrowExpenseMigrator.call(apply: true)
      end
    end

    # 50.00 on 05/01, then another 50.00 the next week: 100.00 held.
    contractor = EscrowLedgerEntry.where(name: "Contractor Escrow").order(:entry_date)
    assert_equal [ 50.00.to_d, 100.00.to_d ], contractor.map(&:running_balance)
    assert_equal 125.00.to_d, EscrowLedgerEntry.find_by(name: "SSI Trailer Escrow").running_balance
  end

  test "the escrow balance is unchanged by the move" do
    legacy_escrow!(50.00, Date.new(2026, 5, 1), "Contractor Escrow")
    legacy_escrow!(125.00, Date.new(2026, 5, 1), "SSI Trailer Escrow")

    summary = -> { OperatingSummary.year(user: users(:one), year: 2026, truck: trucks(:one)).escrow_balance }
    before = summary.call
    assert_equal 175.00.to_d, before

    EscrowExpenseMigrator.call(apply: true)

    assert_equal before, summary.call
  end
end
