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

    if ENV["RESET"] == "true"
      puts "RESET=true: clearing existing records..."
      [TaxPayment, Maintenance, Mileage, FuelLog, Expense, Invoice, CompanyProfile].each(&:delete_all)
    end

    ActiveRecord::Base.transaction do
      import_company(company)
      import_invoices(invoices)
      import_expenses(expenses)
      import_fuel_logs(fuel_logs)
      import_mileages(mileages)
      import_maintenances(maintenances)
      import_tax_payments(tax_payments)
    end

    puts "Import complete."
    puts "Invoices: #{Invoice.count}"
    puts "Expenses: #{Expense.count}"
    puts "Fuel logs: #{FuelLog.count}"
    puts "Mileages: #{Mileage.count}"
    puts "Maintenances: #{Maintenance.count}"
    puts "Tax payments: #{TaxPayment.count}"
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

  def import_company(company)
    return if company.blank?

    profile = CompanyProfile.first_or_initialize
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

  def import_invoices(rows)
    rows.each do |r|
      Invoice.create!(
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

  def import_expenses(rows)
    rows.each do |r|
      Expense.create!(
        expense_date: parse_date(r["expenseDate"] || r["date"] || r["expense_date"]),
        category: (r["category"] || "other").to_s.downcase,
        vendor: r["vendor"] || r["merchant"],
        amount: parse_decimal(r["amount"]),
        gallons: parse_decimal(r["gallons"]),
        notes: r["notes"]
      )
    end
  end

  def import_fuel_logs(rows)
    rows.each do |r|
      FuelLog.create!(
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

  def import_mileages(rows)
    rows.each do |r|
      Mileage.create!(
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

  def import_maintenances(rows)
    rows.each do |r|
      Maintenance.create!(
        maintenance_date: parse_date(r["maintenanceDate"] || r["date"] || r["maintenance_date"]),
        maintenance_type: (r["maintenanceType"] || r["type"] || r["maintenance_type"] || "other").to_s.downcase,
        cost: parse_decimal(r["cost"] || r["amount"]),
        odometer: parse_int(r["odometer"]),
        vendor: r["vendor"] || r["shop"],
        notes: r["notes"]
      )
    end
  end

  def import_tax_payments(rows)
    rows.each do |r|
      TaxPayment.create!(
        payment_date: parse_date(r["paymentDate"] || r["date"] || r["payment_date"]),
        quarter: r["quarter"],
        amount: parse_decimal(r["amount"]),
        notes: r["notes"]
      )
    end
  end
end
