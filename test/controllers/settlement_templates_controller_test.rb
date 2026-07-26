require "test_helper"

class SettlementTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @template = settlement_templates(:kaplan)
  end

  test "pages render" do
    get settlement_templates_url
    assert_response :success

    get new_settlement_template_url
    assert_response :success

    get new_settlement_template_url(starter: 1)
    assert_response :success

    get edit_settlement_template_url(@template)
    assert_response :success

    get apply_settlement_template_url(@template)
    assert_response :success
  end

  test "recording a settlement creates one expense per checked line" do
    assert_difference "Expense.count", 3 do
      post apply_settlement_template_url(@template), params: {
        expense_date: "2026-06-15",
        lines: {
          settlement_template_lines(:occ_acc).id.to_s => { include: "1", amount: "33.46" },
          settlement_template_lines(:trailer_escrow).id.to_s => { include: "1", amount: "125.00" },
          settlement_template_lines(:ky_permit).id.to_s => { include: "1", amount: "130.00" }
        }
      }
    end

    assert_redirected_to settlements_path

    created = Expense.where(expense_date: Date.new(2026, 6, 15)).order(:amount)
    assert created.all? { |expense| expense.settlement_id.present? },
           "every deduction belongs to the settlement that recorded it"
    assert_equal %w[ insurance permits escrow ].sort, created.map(&:category).sort
    assert created.all? { |expense| expense.vendor == "Kaplan" }
    assert created.all? { |expense| expense.truck == trucks(:one) }
    assert created.all? { |expense| expense.settlement_template_line_id.present? }
  end

  test "an unchecked line is skipped" do
    assert_difference "Expense.count", 1 do
      post apply_settlement_template_url(@template), params: {
        expense_date: "2026-06-15",
        lines: {
          settlement_template_lines(:occ_acc).id.to_s => { include: "1", amount: "33.46" },
          settlement_template_lines(:ky_permit).id.to_s => { include: "0", amount: "130.00" }
        }
      }
    end
  end

  test "a zero amount records nothing" do
    assert_no_difference "Expense.count" do
      post apply_settlement_template_url(@template), params: {
        expense_date: "2026-06-15",
        lines: { settlement_template_lines(:occ_acc).id.to_s => { include: "1", amount: "0" } }
      }
    end

    assert_redirected_to apply_settlement_template_path(@template, expense_date: Date.new(2026, 6, 15))
  end

  test "an inactive line cannot be recorded even if submitted" do
    assert_no_difference "Expense.count" do
      post apply_settlement_template_url(@template), params: {
        expense_date: "2026-06-15",
        lines: { settlement_template_lines(:retired).id.to_s => { include: "1", amount: "10.00" } }
      }
    end
  end

  test "an invalid date is refused" do
    assert_no_difference "Expense.count" do
      post apply_settlement_template_url(@template), params: { expense_date: "not-a-date" }
    end

    assert_redirected_to apply_settlement_template_path(@template)
  end

  test "another user's template is not reachable" do
    other = users(:two).settlement_templates.create!(name: "Theirs")

    get apply_settlement_template_url(other)
    assert_response :not_found

    assert_no_difference "Expense.count" do
      post apply_settlement_template_url(other), params: { expense_date: "2026-06-15" }
    end
    assert_response :not_found
  end

  test "recording a settlement captures revenue and deductions as one document" do
    assert_difference [ "Settlement.count", "Expense.count" ], 1 do
      post apply_settlement_template_url(@template), params: {
        expense_date: "2026-07-14",
        settlement: { gross_linehaul: "2600.00", linehaul: "1976.00", fuel_surcharge: "870.00",
                      accessorials: "0", load_count: "1", statement_number: "2873048" },
        lines: { settlement_template_lines(:occ_acc).id.to_s => { include: "1", amount: "33.46" } }
      }
    end

    settlement = Settlement.order(:created_at).last
    assert_equal 2_846.00.to_d, settlement.truck_revenue
    assert_equal 33.46.to_d, settlement.total_deductions
    assert_equal 2_812.54.to_d, settlement.net_balance
    assert_equal settlement, Expense.order(:created_at).last.settlement
    assert_redirected_to settlements_path
  end

  test "revenue alone is enough to record a settlement" do
    assert_difference "Settlement.count", 1 do
      post apply_settlement_template_url(@template), params: {
        expense_date: "2026-07-14",
        settlement: { linehaul: "1976.00", fuel_surcharge: "870.00" }
      }
    end
  end

  test "a statement with neither revenue nor deductions is not recorded" do
    assert_no_difference "Settlement.count" do
      post apply_settlement_template_url(@template), params: {
        expense_date: "2026-07-14",
        lines: { settlement_template_lines(:occ_acc).id.to_s => { include: "1", amount: "0" } }
      }
    end
  end
end
