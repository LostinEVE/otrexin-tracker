# Every statement prints the carrier's own year-to-date 1099 revenue. Keeping it
# gives the books something authoritative to be checked against, which is how a
# missing statement or a double-counted invoice gets caught before a tax return.
class AddYearToDateToSettlements < ActiveRecord::Migration[8.1]
  def change
    add_column :settlements, :ytd_revenue, :decimal, precision: 12, scale: 2
    add_column :settlements, :ytd_load_count, :integer
  end
end
