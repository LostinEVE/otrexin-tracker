# Escrow is money held by the carrier and owed back, not a cost. It gets its
# own ledger so profit and cost per mile never absorb a refundable deposit.
class CreateEscrowLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :escrow_ledger_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :truck, foreign_key: true
      t.references :settlement, foreign_key: true
      t.string :name, null: false
      t.date :entry_date, null: false
      t.decimal :deposit_amount, precision: 12, scale: 2, default: "0.0", null: false
      # The statement's own collected-to-date figure for this escrow.
      t.decimal :running_balance, precision: 12, scale: 2, default: "0.0", null: false
      t.decimal :target, precision: 12, scale: 2
      t.decimal :interest_credited, precision: 12, scale: 2
      t.text :notes
      t.timestamps
    end

    add_index :escrow_ledger_entries, [ :user_id, :entry_date ]
  end
end
