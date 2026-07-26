# A carrier settlement repeats the same deduction lines every week. Storing that
# set once turns fourteen hand-typed expenses into one form.
class CreateSettlementTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :settlement_templates do |t|
      t.references :user, null: false, foreign_key: true
      t.references :truck, foreign_key: true
      t.string :name, null: false
      t.string :vendor
      t.text :notes
      t.timestamps
    end

    create_table :settlement_template_lines do |t|
      t.references :settlement_template, null: false, foreign_key: true
      t.string :label, null: false
      t.string :category, null: false
      t.decimal :amount, precision: 10, scale: 2
      # When the line pays down a known total — plates, a permit, an equipment
      # loan — this is that total, so the remaining balance can be shown instead
      # of being tracked by hand in the notes field.
      t.decimal :balance_target, precision: 12, scale: 2
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    # Lets an expense be traced back to the line that created it, which is what
    # makes the collected/remaining balances exact rather than guessed from text.
    add_reference :expenses, :settlement_template_line, foreign_key: true, null: true
  end
end
