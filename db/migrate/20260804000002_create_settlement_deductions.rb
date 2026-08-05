# The detail layer behind each deduction: the statement's own amortization
# sub-table, kept line by line so a recurring deduction that just reached its
# payoff target is visible as data instead of being lost in a single amount.
class CreateSettlementDeductions < ActiveRecord::Migration[8.1]
  def change
    create_table :settlement_deductions do |t|
      t.references :settlement, null: false, foreign_key: true
      t.string :label, null: false
      t.string :category, null: false
      t.string :detail
      t.decimal :scheduled_amount, precision: 12, scale: 2, default: "0.0", null: false
      t.decimal :collected_this_statement, precision: 12, scale: 2, default: "0.0", null: false
      t.decimal :uncollected, precision: 12, scale: 2, default: "0.0", null: false
      t.decimal :previous_collected, precision: 12, scale: 2, default: "0.0", null: false
      t.decimal :total_collected_to_date, precision: 12, scale: 2, default: "0.0", null: false
      # NULL means the statement prints no balance for this line (a flat weekly
      # deduction); 0.00 means a payoff line that has just reached its target.
      # Coercing either into the other would destroy exactly the fact this
      # table exists to record.
      t.decimal :new_balance, precision: 12, scale: 2
      t.decimal :weekly_amount, precision: 12, scale: 2
      t.decimal :balance_target, precision: 12, scale: 2
      # Populated by the lease audit once lease terms are on file.
      t.boolean :lease_authorized
      t.timestamps
    end
  end
end
