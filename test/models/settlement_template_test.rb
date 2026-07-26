require "test_helper"

class SettlementTemplateTest < ActiveSupport::TestCase
  test "only active lines are offered and totalled" do
    template = settlement_templates(:kaplan)

    assert_equal 4, template.lines.count
    assert_equal 3, template.active_lines.size
    assert_equal 288.46.to_d, template.expected_total
  end

  test "the starter set is a usable weekly settlement" do
    lines = SettlementTemplate.starter_lines

    assert_equal 14, lines.size
    assert lines.all? { |line| Expense::CATEGORIES.key?(line.category) },
           "every starter line must use a real expense category"
    assert_includes lines.map(&:category), "escrow"

    # A real Kaplan statement scheduled 987.19 of deductions for the following
    # week. The active starter lines add to the same figure, which is the check
    # that the set is complete and the paid-off plate line is correctly off.
    active_total = lines.select(&:active?).sum { |line| line.amount.to_d }
    assert_equal 987.19.to_d, active_total
  end

  test "a line reports what it has collected from the expenses it created" do
    line = settlement_template_lines(:ky_permit)

    3.times do |index|
      Expense.create!(user: users(:one), truck: trucks(:one), settlement_template_line: line,
                      expense_date: Date.new(2026, 6, 1) + (index * 7), category: "permits",
                      amount: 130, notes: line.label)
    end

    assert_equal 390.to_d, line.collected
    assert_equal 910.to_d, line.remaining
    assert_not line.paid_off?
  end

  test "a balance never goes past paid off" do
    line = settlement_template_lines(:ky_permit)
    Expense.create!(user: users(:one), truck: trucks(:one), settlement_template_line: line,
                    expense_date: Date.new(2026, 6, 1), category: "permits", amount: 5_000,
                    notes: line.label)

    assert_equal 0.to_d, line.remaining
    assert line.paid_off?
  end

  test "a line without a target tracks no balance" do
    line = settlement_template_lines(:occ_acc)

    assert_not line.tracks_balance?
    assert_nil line.remaining
  end

  test "deleting a template keeps the expenses it created" do
    template = settlement_templates(:kaplan)
    line = settlement_template_lines(:occ_acc)
    expense = Expense.create!(user: users(:one), truck: trucks(:one), settlement_template_line: line,
                              expense_date: Date.new(2026, 6, 1), category: "insurance", amount: 33.46)

    template.destroy!

    assert expense.reload.persisted?
    assert_nil expense.settlement_template_line_id
  end
end
