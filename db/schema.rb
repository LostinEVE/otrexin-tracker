# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_04_000005) do
  create_table "company_profiles", force: :cascade do |t|
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "company_name"
    t.datetime "created_at", null: false
    t.string "dot_number"
    t.string "email"
    t.string "mc_number"
    t.string "phone"
    t.string "state"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "zip"
    t.index ["user_id"], name: "index_company_profiles_on_user_id"
  end

  create_table "depreciation_assets", force: :cascade do |t|
    t.string "asset_type", null: false
    t.decimal "cost_basis", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.string "depreciation_method", default: "straight_line", null: false
    t.string "name", null: false
    t.text "notes"
    t.date "placed_in_service_date", null: false
    t.integer "recovery_period_years", null: false
    t.decimal "salvage_value", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "truck_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["truck_id"], name: "index_depreciation_assets_on_truck_id"
    t.index ["user_id", "placed_in_service_date"], name: "idx_on_user_id_placed_in_service_date_0fe1fd55a2"
    t.index ["user_id"], name: "index_depreciation_assets_on_user_id"
  end

  create_table "escrow_ledger_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "deposit_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.date "entry_date", null: false
    t.decimal "interest_credited", precision: 12, scale: 2
    t.string "name", null: false
    t.text "notes"
    t.decimal "running_balance", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "settlement_id"
    t.decimal "target", precision: 12, scale: 2
    t.integer "truck_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["settlement_id"], name: "index_escrow_ledger_entries_on_settlement_id"
    t.index ["truck_id"], name: "index_escrow_ledger_entries_on_truck_id"
    t.index ["user_id", "entry_date"], name: "index_escrow_ledger_entries_on_user_id_and_entry_date"
    t.index ["user_id"], name: "index_escrow_ledger_entries_on_user_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.decimal "amount"
    t.string "category"
    t.datetime "created_at", null: false
    t.date "expense_date"
    t.decimal "gallons"
    t.text "notes"
    t.integer "settlement_id"
    t.integer "settlement_template_line_id"
    t.integer "truck_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "vendor"
    t.index ["expense_date"], name: "index_expenses_on_expense_date"
    t.index ["settlement_id"], name: "index_expenses_on_settlement_id"
    t.index ["settlement_template_line_id"], name: "index_expenses_on_settlement_template_line_id"
    t.index ["truck_id"], name: "index_expenses_on_truck_id"
    t.index ["user_id", "truck_id"], name: "index_expenses_on_user_id_and_truck_id"
    t.index ["user_id"], name: "index_expenses_on_user_id"
  end

  create_table "fuel_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "fuel_date"
    t.decimal "gallons"
    t.string "location"
    t.text "notes"
    t.integer "odometer"
    t.decimal "price_per_gallon"
    t.string "station"
    t.decimal "total_cost"
    t.integer "truck_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["truck_id"], name: "index_fuel_logs_on_truck_id"
    t.index ["user_id", "truck_id"], name: "index_fuel_logs_on_user_id_and_truck_id"
    t.index ["user_id"], name: "index_fuel_logs_on_user_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.decimal "amount"
    t.datetime "created_at", null: false
    t.string "customer_name"
    t.date "delivery_date"
    t.date "invoice_date"
    t.string "invoice_number"
    t.string "load_number"
    t.text "notes"
    t.string "pickup"
    t.date "pickup_date"
    t.integer "piece_count"
    t.string "product_description"
    t.decimal "rate_per_piece"
    t.string "status"
    t.integer "truck_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["invoice_date"], name: "index_invoices_on_invoice_date"
    t.index ["status"], name: "index_invoices_on_status"
    t.index ["truck_id"], name: "index_invoices_on_truck_id"
    t.index ["user_id", "truck_id"], name: "index_invoices_on_user_id_and_truck_id"
    t.index ["user_id"], name: "index_invoices_on_user_id"
  end

  create_table "lease_terms", force: :cascade do |t|
    t.decimal "balance_target", precision: 12, scale: 2
    t.string "category"
    t.datetime "created_at", null: false
    t.string "kind", default: "deduction", null: false
    t.string "label"
    t.text "notes"
    t.decimal "percentage", precision: 6, scale: 3
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.decimal "weekly_amount", precision: 12, scale: 2
    t.index ["user_id"], name: "index_lease_terms_on_user_id"
  end

  create_table "maintenances", force: :cascade do |t|
    t.decimal "cost"
    t.datetime "created_at", null: false
    t.date "maintenance_date"
    t.string "maintenance_type"
    t.text "notes"
    t.integer "odometer"
    t.integer "truck_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "vendor"
    t.index ["maintenance_date"], name: "index_maintenances_on_maintenance_date"
    t.index ["truck_id"], name: "index_maintenances_on_truck_id"
    t.index ["user_id", "truck_id"], name: "index_maintenances_on_user_id_and_truck_id"
    t.index ["user_id"], name: "index_maintenances_on_user_id"
  end

  create_table "per_diem_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "daily_rate", precision: 10, scale: 2, null: false
    t.date "end_date", null: false
    t.text "notes"
    t.integer "qualifying_days", null: false
    t.date "start_date", null: false
    t.integer "truck_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["truck_id"], name: "index_per_diem_entries_on_truck_id"
    t.index ["user_id", "start_date"], name: "index_per_diem_entries_on_user_id_and_start_date"
    t.index ["user_id"], name: "index_per_diem_entries_on_user_id"
  end

  create_table "settlement_accessorials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "gross_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.string "label", null: false
    t.decimal "net_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "percentage_applied", precision: 6, scale: 3, null: false
    t.integer "settlement_id", null: false
    t.datetime "updated_at", null: false
    t.index ["settlement_id"], name: "index_settlement_accessorials_on_settlement_id"
  end

  create_table "settlement_deductions", force: :cascade do |t|
    t.decimal "balance_target", precision: 12, scale: 2
    t.string "category", null: false
    t.decimal "collected_this_statement", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.string "detail"
    t.string "label", null: false
    t.boolean "lease_authorized"
    t.decimal "new_balance", precision: 12, scale: 2
    t.decimal "previous_collected", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "scheduled_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "settlement_id", null: false
    t.decimal "total_collected_to_date", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "uncollected", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.decimal "weekly_amount", precision: 12, scale: 2
    t.index ["settlement_id"], name: "index_settlement_deductions_on_settlement_id"
  end

  create_table "settlement_template_lines", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.decimal "amount", precision: 10, scale: 2
    t.decimal "balance_target", precision: 12, scale: 2
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.integer "position", default: 0, null: false
    t.integer "settlement_template_id", null: false
    t.datetime "updated_at", null: false
    t.index ["settlement_template_id"], name: "index_settlement_template_lines_on_settlement_template_id"
  end

  create_table "settlement_templates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "truck_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "vendor"
    t.index ["truck_id"], name: "index_settlement_templates_on_truck_id"
    t.index ["user_id"], name: "index_settlement_templates_on_user_id"
  end

  create_table "settlements", force: :cascade do |t|
    t.decimal "accessorials", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.decimal "fuel_advance", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "fuel_surcharge", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "gross_linehaul", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "linehaul", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "load_count"
    t.integer "miles"
    t.text "notes"
    t.decimal "other_income", precision: 12, scale: 2, default: "0.0", null: false
    t.text "pay_deviation"
    t.string "payer"
    t.decimal "realized_fuel_surcharge_rate", precision: 10, scale: 8
    t.decimal "realized_linehaul_rate", precision: 10, scale: 8
    t.integer "settlement_template_id"
    t.string "source_filename"
    t.date "statement_date", null: false
    t.string "statement_number"
    t.integer "truck_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "ytd_load_count"
    t.decimal "ytd_revenue", precision: 12, scale: 2
    t.index ["settlement_template_id"], name: "index_settlements_on_settlement_template_id"
    t.index ["truck_id"], name: "index_settlements_on_truck_id"
    t.index ["user_id", "statement_date"], name: "index_settlements_on_user_id_and_statement_date"
    t.index ["user_id", "statement_number"], name: "index_settlements_on_user_id_and_statement_number"
    t.index ["user_id"], name: "index_settlements_on_user_id"
  end

  create_table "tax_payments", force: :cascade do |t|
    t.decimal "amount"
    t.datetime "created_at", null: false
    t.text "notes"
    t.date "payment_date"
    t.string "quarter"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_tax_payments_on_user_id"
  end

  create_table "trucks", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "baseline_odometer"
    t.datetime "created_at", null: false
    t.string "make"
    t.string "model"
    t.string "name", null: false
    t.string "unit_number"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "vin"
    t.integer "year"
    t.index ["user_id", "name"], name: "index_trucks_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_trucks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "company_profiles", "users"
  add_foreign_key "depreciation_assets", "trucks"
  add_foreign_key "depreciation_assets", "users"
  add_foreign_key "escrow_ledger_entries", "settlements"
  add_foreign_key "escrow_ledger_entries", "trucks"
  add_foreign_key "escrow_ledger_entries", "users"
  add_foreign_key "expenses", "settlement_template_lines"
  add_foreign_key "expenses", "settlements"
  add_foreign_key "expenses", "trucks"
  add_foreign_key "expenses", "users"
  add_foreign_key "fuel_logs", "trucks"
  add_foreign_key "fuel_logs", "users"
  add_foreign_key "invoices", "trucks"
  add_foreign_key "invoices", "users"
  add_foreign_key "lease_terms", "users"
  add_foreign_key "maintenances", "trucks"
  add_foreign_key "maintenances", "users"
  add_foreign_key "per_diem_entries", "trucks"
  add_foreign_key "per_diem_entries", "users"
  add_foreign_key "settlement_accessorials", "settlements"
  add_foreign_key "settlement_deductions", "settlements"
  add_foreign_key "settlement_template_lines", "settlement_templates"
  add_foreign_key "settlement_templates", "trucks"
  add_foreign_key "settlement_templates", "users"
  add_foreign_key "settlements", "settlement_templates"
  add_foreign_key "settlements", "trucks"
  add_foreign_key "settlements", "users"
  add_foreign_key "tax_payments", "users"
  add_foreign_key "trucks", "users"
end
