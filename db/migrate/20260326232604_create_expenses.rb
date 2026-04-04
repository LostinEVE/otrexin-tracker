class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.date :expense_date
      t.string :category
      t.string :vendor
      t.decimal :amount
      t.text :notes

      t.timestamps
    end
  end
end
