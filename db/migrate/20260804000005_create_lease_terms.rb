# What the Kaplan lease actually authorizes, entered once from the paper:
# permitted deduction categories with their stated weekly amounts, escrow
# terms, and the agreed pay percentages. 49 CFR Part 376 requires the lease to
# specify permitted deductions; this table is the app's copy of that list, so
# every settlement line can be checked against it.
class CreateLeaseTerms < ActiveRecord::Migration[8.1]
  def change
    create_table :lease_terms do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false, default: "deduction"
      t.string :label
      t.string :category
      t.decimal :weekly_amount, precision: 12, scale: 2
      t.decimal :balance_target, precision: 12, scale: 2
      t.decimal :percentage, precision: 6, scale: 3
      t.text :notes
      t.timestamps
    end
  end
end
