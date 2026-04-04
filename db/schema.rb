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

ActiveRecord::Schema[8.1].define(version: 2026_03_27_005134) do
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

  create_table "expenses", force: :cascade do |t|
    t.decimal "amount"
    t.string "category"
    t.datetime "created_at", null: false
    t.date "expense_date"
    t.decimal "gallons"
    t.text "notes"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "vendor"
    t.index ["expense_date"], name: "index_expenses_on_expense_date"
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
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
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
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["invoice_date"], name: "index_invoices_on_invoice_date"
    t.index ["status"], name: "index_invoices_on_status"
    t.index ["user_id"], name: "index_invoices_on_user_id"
  end

  create_table "maintenances", force: :cascade do |t|
    t.decimal "cost"
    t.datetime "created_at", null: false
    t.date "maintenance_date"
    t.string "maintenance_type"
    t.text "notes"
    t.integer "odometer"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "vendor"
    t.index ["maintenance_date"], name: "index_maintenances_on_maintenance_date"
    t.index ["user_id"], name: "index_maintenances_on_user_id"
  end

  create_table "mileages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "destination"
    t.string "load_number"
    t.decimal "miles"
    t.text "notes"
    t.string "origin"
    t.decimal "revenue"
    t.date "trip_date"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["trip_date"], name: "index_mileages_on_trip_date"
    t.index ["user_id"], name: "index_mileages_on_user_id"
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

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "company_profiles", "users"
  add_foreign_key "expenses", "users"
  add_foreign_key "fuel_logs", "users"
  add_foreign_key "invoices", "users"
  add_foreign_key "maintenances", "users"
  add_foreign_key "mileages", "users"
  add_foreign_key "tax_payments", "users"
end
