class AddUserRefsToCoreTables < ActiveRecord::Migration[8.1]
  def change
    add_reference :invoices, :user, foreign_key: true
    add_reference :expenses, :user, foreign_key: true
    add_reference :fuel_logs, :user, foreign_key: true
    add_reference :mileages, :user, foreign_key: true
    add_reference :maintenances, :user, foreign_key: true
    add_reference :tax_payments, :user, foreign_key: true
    add_reference :company_profiles, :user, foreign_key: true

    reversible do |dir|
      dir.up do
        user = User.first_or_create!(email: "owner@local.app", password: "changeme123", password_confirmation: "changeme123")

        execute "UPDATE invoices SET user_id = #{user.id} WHERE user_id IS NULL"
        execute "UPDATE expenses SET user_id = #{user.id} WHERE user_id IS NULL"
        execute "UPDATE fuel_logs SET user_id = #{user.id} WHERE user_id IS NULL"
        execute "UPDATE mileages SET user_id = #{user.id} WHERE user_id IS NULL"
        execute "UPDATE maintenances SET user_id = #{user.id} WHERE user_id IS NULL"
        execute "UPDATE tax_payments SET user_id = #{user.id} WHERE user_id IS NULL"
        execute "UPDATE company_profiles SET user_id = #{user.id} WHERE user_id IS NULL"

        change_column_null :invoices, :user_id, false
        change_column_null :expenses, :user_id, false
        change_column_null :fuel_logs, :user_id, false
        change_column_null :mileages, :user_id, false
        change_column_null :maintenances, :user_id, false
        change_column_null :tax_payments, :user_id, false
        change_column_null :company_profiles, :user_id, false
      end
    end
  end
end
