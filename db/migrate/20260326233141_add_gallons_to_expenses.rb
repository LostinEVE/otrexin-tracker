class AddGallonsToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses, :gallons, :decimal
  end
end
