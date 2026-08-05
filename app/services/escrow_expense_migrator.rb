# Moves legacy escrow-category expense rows into the escrow ledger. Escrow
# recorded before the ledger existed sits in expenses; each row becomes a
# ledger entry and the expense row goes away — moved, not deleted.
#
# Dry run by default: call with apply: true (rake escrow:migrate_expenses
# APPLY=1) only after reviewing the reported count and total.
#
# Running balances accumulate from zero per escrow name. That is correct
# chronologically: legacy rows predate ledger entries created from imported
# statements, and a statement's own collected-to-date figure already counts
# every prior collection.
class EscrowExpenseMigrator
  Report = Struct.new(:rows, :total, :applied, keyword_init: true)

  def self.call(apply: false)
    rows = Expense.where(category: "escrow").order(:expense_date, :id).to_a
    total = rows.sum(0.to_d) { |expense| expense.amount.to_d }

    move(rows) if apply

    Report.new(rows: rows.size, total: total, applied: apply)
  end

  def self.move(rows)
    balances = Hash.new(0.to_d)

    ActiveRecord::Base.transaction do
      rows.each do |expense|
        name = name_for(expense)
        key = [ expense.user_id, expense.truck_id, name ]
        balances[key] += expense.amount.to_d

        EscrowLedgerEntry.create!(
          user_id: expense.user_id,
          truck_id: expense.truck_id,
          settlement_id: expense.settlement_id,
          name: name,
          entry_date: expense.expense_date,
          deposit_amount: expense.amount.to_d,
          running_balance: balances[key],
          notes: expense.notes
        )
        expense.destroy!
      end
    end
  end

  # Imported escrow expenses carry "label — detail" notes; the label is the
  # escrow's name. A hand-typed note stands in as the name, which is the best
  # available record of which escrow it was.
  def self.name_for(expense)
    expense.notes.to_s.split(" — ").first.presence || "Escrow"
  end
end
