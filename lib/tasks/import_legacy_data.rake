require "csv"

namespace :data do
  desc "Import legacy JSON data into Rails models. Usage: rake data:import_legacy_json[legacy.json] RESET=true"
  task :import_legacy_json, [ :file_path ] => :environment do |_t, args|
    path = args[:file_path] || ENV["FILE"]
    raise "Provide file path: rake data:import_legacy_json[path/to/file.json]" if path.blank?

    unless File.exist?(path)
      raise "File not found: #{path}"
    end

    payload = JSON.parse(File.read(path))

    # Accept either direct object or wrapped { data: {...} }
    root = payload["data"].is_a?(Hash) ? payload["data"] : payload

    invoices = pick(root, "invoices", "invoiceHistory")
    expenses = pick(root, "expenses", "expenseHistory")
    fuel_logs = pick(root, "fuel_logs", "fuelLogs", "fuelLog")
    mileages = pick(root, "mileages", "mileage", "mileageEntries", "trips")
    maintenances = pick(root, "maintenances", "maintenance", "maintenanceRecords")
    tax_payments = pick(root, "tax_payments", "taxPayments")

    settings = root["settings"].is_a?(Hash) ? root["settings"] : {}
    company = (settings["company"] || root["company"] || {}).is_a?(Hash) ? (settings["company"] || root["company"]) : {}
    import_user = find_or_create_import_user!

    if ENV["RESET"] == "true"
      puts "RESET=true: clearing existing records for #{import_user.email}..."
      import_user.tax_payments.delete_all
      import_user.maintenances.delete_all
      import_user.mileages.delete_all
      import_user.fuel_logs.delete_all
      import_user.expenses.delete_all
      import_user.invoices.delete_all
      import_user.company_profile&.destroy!
    end

    ActiveRecord::Base.transaction do
      import_company(company, import_user)
      import_invoices(invoices, import_user)
      import_expenses(expenses, import_user)
      import_fuel_logs(fuel_logs, import_user)
      import_mileages(mileages, import_user)
      import_maintenances(maintenances, import_user)
      import_tax_payments(tax_payments, import_user)
    end

    puts "Import complete for #{import_user.email}."
    puts "Invoices: #{import_user.invoices.count}"
    puts "Expenses: #{import_user.expenses.count}"
    puts "Fuel logs: #{import_user.fuel_logs.count}"
    puts "Mileages: #{import_user.mileages.count}"
    puts "Maintenances: #{import_user.maintenances.count}"
    puts "Tax payments: #{import_user.tax_payments.count}"
  end

  desc "Import expenses from CSV. Usage: rake data:import_expenses_csv[path/to/expenses.csv]"
  task :import_expenses_csv, [ :file_path ] => :environment do |_t, args|
    path = args[:file_path] || ENV["FILE"]
    raise "Provide file path: rake data:import_expenses_csv[path/to/file.csv]" if path.blank?

    unless File.exist?(path)
      raise "File not found: #{path}"
    end

    import_user = find_or_create_import_user!
    imported = 0
    skipped = 0
    current_truck = nil

    CSV.foreach(path, headers: true, header_converters: ->(h) { h.to_s.delete_prefix("\uFEFF").strip }) do |row|
      values = row.to_h.transform_values { |v| v.is_a?(String) ? v.strip : v }
      next if values.values.compact.all?(&:blank?)

      truck = values["Truck"].presence
      date_value = values["Date"].presence
      category = values["Category"].presence
      vendor = values["Vendor"].presence
      amount = values["Amount"].presence
      notes = values["Notes"].presence

      # Old reports often include a section heading row like "Truck Name - EXPENSES".
      if truck.present? && date_value.blank? && category.blank? && vendor.blank? && amount.blank? && notes.blank?
        current_truck = truck.sub(/\s*-\s*EXPENSES\s*\z/i, "").strip
        skipped += 1
        next
      end

      expense_date = parse_date(date_value)
      if expense_date.nil?
        skipped += 1
        next
      end

      truck_name = truck.presence || current_truck
      combined_notes = [ notes, ("Truck: #{truck_name}" if truck_name.present?) ].compact.join(" | ")

      Expense.create!(
        user: import_user,
        expense_date: expense_date,
        category: (category || "other").downcase,
        vendor: vendor,
        amount: parse_decimal(amount),
        notes: combined_notes.presence
      )
      imported += 1
    end

    puts "Expense CSV import complete for #{import_user.email}."
    puts "Imported rows: #{imported}"
    puts "Skipped rows: #{skipped}"
    puts "Total expenses for user: #{import_user.expenses.count}"
  end

  def find_or_create_import_user!
    email = ENV["IMPORT_USER_EMAIL"].presence || "owner@local.app"
    password = ENV["IMPORT_USER_PASSWORD"].presence || "changeme123"

    User.find_or_create_by!(email: email) do |user|
      user.password = password
      user.password_confirmation = password
    end
  end

  def pick(root, *keys)
    key = keys.find { |k| root[k].is_a?(Array) }
    key ? root[key] : []
  end

  def parse_date(v)
    return nil if v.blank?
    Date.parse(v.to_s)
  rescue ArgumentError
    nil
  end

  def parse_decimal(v)
    return nil if v.nil? || v == ""
    BigDecimal(v.to_s)
  rescue ArgumentError
    nil
  end

  def parse_int(v)
    return nil if v.nil? || v == ""
    v.to_i
  end

  def import_company(company, user)
    return if company.blank?

    profile = CompanyProfile.find_or_initialize_by(user: user)
    profile.assign_attributes(
      company_name: company["companyName"] || company["name"] || company["company_name"],
      address_line1: company["address1"] || company["address_line1"],
      address_line2: company["address2"] || company["address_line2"],
      city: company["city"],
      state: company["state"],
      zip: company["zip"] || company["zipCode"],
      phone: company["phone"],
      email: company["email"],
      dot_number: company["dotNumber"] || company["dot_number"],
      mc_number: company["mcNumber"] || company["mc_number"]
    )
    profile.save!
  end

  def import_invoices(rows, user)
    rows.each do |r|
      Invoice.create!(
        user: user,
        invoice_number: r["invoiceNumber"] || r["invoice_number"],
        invoice_date: parse_date(r["invoiceDate"] || r["invoice_date"] || r["date"]),
        customer_name: r["customerName"] || r["customer_name"],
        load_number: r["loadNumber"] || r["load_number"],
        delivery_date: parse_date(r["dateDelivered"] || r["deliveryDate"] || r["delivery_date"]),
        amount: parse_decimal(r["amount"]),
        product_description: r["productDescription"] || r["product_description"],
        piece_count: parse_int(r["pieceCount"] || r["piece_count"]),
        rate_per_piece: parse_decimal(r["ratePerPiece"] || r["rate_per_piece"]),
        status: (r["paymentStatus"] || r["status"] || "unpaid").to_s.downcase,
        notes: r["notes"]
      )
    end
  end

  def import_expenses(rows, user)
    rows.each do |r|
      Expense.create!(
        user: user,
        expense_date: parse_date(r["expenseDate"] || r["date"] || r["expense_date"]),
        category: (r["category"] || "other").to_s.downcase,
        vendor: r["vendor"] || r["merchant"],
        amount: parse_decimal(r["amount"]),
        gallons: parse_decimal(r["gallons"]),
        notes: r["notes"]
      )
    end
  end

  def import_fuel_logs(rows, user)
    rows.each do |r|
      FuelLog.create!(
        user: user,
        fuel_date: parse_date(r["fuelDate"] || r["date"] || r["fuel_date"]),
        odometer: parse_int(r["odometer"]),
        gallons: parse_decimal(r["gallons"]),
        price_per_gallon: parse_decimal(r["pricePerGallon"] || r["price_per_gallon"]),
        total_cost: parse_decimal(r["totalCost"] || r["total_cost"] || r["amount"]),
        location: r["location"],
        station: r["station"] || r["vendor"],
        notes: r["notes"]
      )
    end
  end

  def import_mileages(rows, user)
    rows.each do |r|
      Mileage.create!(
        user: user,
        trip_date: parse_date(r["tripDate"] || r["date"] || r["trip_date"]),
        load_number: r["loadNumber"] || r["load_number"],
        origin: r["origin"],
        destination: r["destination"],
        miles: parse_decimal(r["miles"]),
        revenue: parse_decimal(r["revenue"] || r["income"]),
        notes: r["notes"]
      )
    end
  end

  def import_maintenances(rows, user)
    rows.each do |r|
      Maintenance.create!(
        user: user,
        maintenance_date: parse_date(r["maintenanceDate"] || r["date"] || r["maintenance_date"]),
        maintenance_type: (r["maintenanceType"] || r["type"] || r["maintenance_type"] || "other").to_s.downcase,
        cost: parse_decimal(r["cost"] || r["amount"]),
        odometer: parse_int(r["odometer"]),
        vendor: r["vendor"] || r["shop"],
        notes: r["notes"]
      )
    end
  end

  def import_tax_payments(rows, user)
    rows.each do |r|
      TaxPayment.create!(
        user: user,
        payment_date: parse_date(r["paymentDate"] || r["date"] || r["payment_date"]),
        quarter: r["quarter"],
        amount: parse_decimal(r["amount"]),
        notes: r["notes"]
      )
    end
  end
end
