require "test_helper"

class ExpenseAuditTest < ActiveSupport::TestCase
  def expense(vendor:, notes: nil, category: "fuel", amount: 100, gallons: nil, date: Date.new(2026, 3, 1))
    Expense.create!(user: users(:one), truck: trucks(:one), expense_date: date,
                    category: category, vendor: vendor, notes: notes, amount: amount, gallons: gallons)
  end

  def audit
    ExpenseAudit.new(user: users(:one))
  end

  # Every case below is a real entry that was sitting under Fuel.
  test "reads the vendor and note to spot a wrong category" do
    {
      { vendor: "Sapp Bros", notes: "Oil and lube all drive brake pads changed new drums, 8 new drive tires" } => "maintenance",
      { vendor: "Ridgerunner welding", notes: "Had to weld battery box bracket" } => "maintenance",
      { vendor: "Blue Beacon", notes: nil } => "truck_wash_hopper_washout",
      { vendor: "A1 Truck Wash", notes: "Hopper washout" } => "truck_wash_hopper_washout",
      { vendor: "Pa Toll plaza", notes: "PA TOLL" } => "tolls",
      { vendor: "Glenn Kersey", notes: "Trailer rent" } => "trailer_lease",
      { vendor: "JR Hensley", notes: "Truck payment 28500 left" } => "truck_payment",
      { vendor: "MBW Transportation", notes: "5% lease cost" } => "settlement_fee",
      { vendor: "Jeff Whisman", notes: "110.00 towards 900 plate fee" } => "permits",
      { vendor: "AT&T", notes: "Cell" } => "phone_internet",
      { vendor: "Lambert Towing", notes: "Truck sank in driveway" } => "towing",
      { vendor: "Kaplan", notes: "Trailer escrow" } => "escrow",
      { vendor: "Kaplan", notes: "E-Log wkly" } => "eld_dashcam",
      { vendor: "Kaplan", notes: "Bobtail Ins" } => "insurance"
    }.each do |attributes, expected|
      record = expense(**attributes)
      assert_equal expected, ExpenseAudit.suggest_for(record),
                   "#{attributes[:vendor]} / #{attributes[:notes]} should read as #{expected}"
      record.destroy!
    end
  end

  test "a correctly filed expense is left alone" do
    expense(vendor: "Pilot", notes: nil, category: "fuel", amount: 800, gallons: 150)

    assert_empty audit.miscategorized
  end

  test "a legacy category name is flagged and mapped back" do
    record = Expense.new(user: users(:one), truck: trucks(:one), expense_date: Date.new(2025, 12, 23),
                         category: "Maintenance & repairs", vendor: "Worldwide Kenworth",
                         notes: "Air valve", amount: 34.85)
    record.save!(validate: false)

    finding = audit.unknown_categories.find { |f| f.expense == record }

    assert finding, "a category outside the current list must be flagged"
    assert_equal "maintenance", finding.suggested_category
  end

  test "a price per gallon typed into the amount is caught" do
    record = expense(vendor: "Petro", amount: 5.05, gallons: 122.66, date: Date.new(2026, 6, 16))

    finding = audit.suspicious_amounts.find { |f| f.expense == record }

    assert finding
    assert_includes finding.reason, "price per gallon"
  end

  test "a normal fuel purchase is not called suspicious" do
    expense(vendor: "Petro", amount: 620.54, gallons: 122.66)

    assert_empty audit.suspicious_amounts
  end

  test "the same charge entered twice is flagged once" do
    2.times { expense(vendor: "Petro", notes: "Knoxville", amount: 569.48, date: Date.new(2026, 2, 22)) }

    assert_equal 1, audit.duplicates.size
  end

  test "two different charges on one day are not duplicates" do
    expense(vendor: "Petro", amount: 569.48, date: Date.new(2026, 2, 22))
    expense(vendor: "Loves", amount: 120.00, date: Date.new(2026, 2, 22))

    assert_empty audit.duplicates
  end

  test "the audit never reaches another user's expenses" do
    other = Expense.create!(user: users(:two), truck: trucks(:three), expense_date: Date.new(2026, 3, 1),
                            category: "fuel", vendor: "Blue Beacon", amount: 100)

    assert_not_includes audit.findings.map(&:expense), other
  end
end
