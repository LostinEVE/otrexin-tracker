require "test_helper"

# Both directions matter: a clean settlement must produce zero flags — a
# false positive erodes trust as fast as a miss.
class LeaseAuditTest < ActiveSupport::TestCase
  def term!(kind: "deduction", label: nil, category: nil, weekly: nil, target: nil, percentage: nil)
    users(:one).lease_terms.create!(kind: kind, label: label, category: category,
                                    weekly_amount: weekly, balance_target: target,
                                    percentage: percentage)
  end

  def settlement!(rate: 0.76.to_d, number: "S1")
    users(:one).settlements.create!(truck: trucks(:one), statement_date: Date.new(2026, 7, 31),
                                    statement_number: number, realized_linehaul_rate: rate)
  end

  def deduction!(settlement, label, category: "other", scheduled: 10.00, weekly: 10.00)
    settlement.settlement_deductions.create!(
      label: label, category: category, scheduled_amount: scheduled,
      collected_this_statement: scheduled, weekly_amount: weekly
    )
  end

  def escrow!(settlement, name, deposit: 50.00, balance: 400.00, target: 500.00)
    users(:one).escrow_ledger_entries.create!(
      truck: trucks(:one), settlement: settlement, name: name,
      entry_date: settlement.statement_date, deposit_amount: deposit,
      running_balance: balance, target: target
    )
  end

  def audit
    LeaseAudit.new(user: users(:one))
  end

  test "a settlement matching the lease produces zero flags" do
    term!(label: "Bobtail Insurance", weekly: 6.92)
    term!(category: "permits", weekly: 150.00)
    term!(kind: "escrow", label: "Contractor Escrow", weekly: 50.00, target: 500.00)
    term!(kind: "pay_percentage", label: "Line Haul Pay", percentage: 76)

    settlement = settlement!
    deduction!(settlement, "Bobtail Insurance", category: "insurance", scheduled: 6.92, weekly: 6.92)
    deduction!(settlement, "Plates", category: "permits", scheduled: 150.00, weekly: 150.00)
    escrow!(settlement, "Contractor Escrow")

    assert_empty audit.findings
  end

  test "a deduction with no authorized term produces exactly one flag naming it" do
    term!(label: "Bobtail Insurance", weekly: 6.92)
    settlement = settlement!
    deduction!(settlement, "Bobtail Insurance", category: "insurance", scheduled: 6.92, weekly: 6.92)
    deduction!(settlement, "Mystery Fee", scheduled: 45.00, weekly: 45.00)

    findings = audit.findings
    assert_equal 1, findings.size
    assert_equal :unauthorized_deduction, findings.first.kind
    assert_equal "Mystery Fee", findings.first.label
    assert_includes findings.first.reason, "review"
  end

  test "a deduction above its stated weekly amount is flagged" do
    term!(label: "Plates", weekly: 75.00)
    settlement = settlement!
    deduction!(settlement, "Plates", category: "permits", scheduled: 150.00, weekly: 150.00)

    findings = audit.findings
    assert_equal 1, findings.size
    assert_equal :excessive_deduction, findings.first.kind
    assert_includes findings.first.reason, "75.00"
  end

  test "escrow held beyond the lease's stated target is flagged" do
    term!(kind: "escrow", label: "Contractor Escrow", weekly: 50.00, target: 500.00)
    settlement = settlement!
    escrow!(settlement, "Contractor Escrow", balance: 600.00)

    findings = audit.findings
    assert_equal 1, findings.size
    assert_equal :escrow_over_target, findings.first.kind
  end

  test "a realized percentage below the agreed rate is flagged" do
    term!(kind: "pay_percentage", label: "Line Haul Pay", percentage: 76)
    settlement!(rate: 0.75.to_d)

    findings = audit.findings
    assert_equal 1, findings.size
    assert_equal :underpaid_percentage, findings.first.kind
  end

  test "every flag cites its settlement and no flag states a conclusion" do
    settlement = settlement!(number: "00999003")
    deduction!(settlement, "Mystery Fee")

    finding = audit.findings.first
    assert_equal settlement, finding.settlement
    assert_includes LeaseAudit::DISCLAIMER, "not legal advice"
    assert_not_includes finding.reason.downcase, "illegal"
    assert_not_includes finding.reason.downcase, "violation"
  end

  test "annotate! records which deductions matched an authorized term" do
    term!(label: "Bobtail Insurance", weekly: 6.92)
    settlement = settlement!
    matched = deduction!(settlement, "Bobtail Insurance", category: "insurance", scheduled: 6.92, weekly: 6.92)
    unmatched = deduction!(settlement, "Mystery Fee")

    audit.annotate!

    assert_equal true, matched.reload.lease_authorized
    assert_equal false, unmatched.reload.lease_authorized
  end
end
