require "test_helper"

# Both directions matter: a clean settlement must produce zero flags — a
# false positive erodes trust as fast as a miss.
class LeaseAuditTest < ActiveSupport::TestCase
  def term!(kind: "deduction", label: nil, category: nil, weekly: nil, target: nil,
            percentage: nil, from: nil)
    users(:one).lease_terms.create!(kind: kind, label: label, category: category,
                                    weekly_amount: weekly, balance_target: target,
                                    percentage: percentage, effective_from: from)
  end

  def settlement!(rate: 0.76.to_d, number: "S1", date: Date.new(2026, 7, 31), deviation: nil)
    users(:one).settlements.create!(truck: trucks(:one), statement_date: date,
                                    statement_number: number, realized_linehaul_rate: rate,
                                    pay_deviation: deviation)
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
    # The escrow line appears in the deduction detail too; the escrow-kind
    # term must authorize it — escrow is not an unauthorized deduction.
    deduction!(settlement, "Contractor Escrow", category: "escrow", scheduled: 50.00, weekly: 50.00)
    escrow!(settlement, "Contractor Escrow")

    assert_empty audit.findings
  end

  test "a superseded term judges old settlements by its own era" do
    # The old trailer cost 20.00/week until the swap; the new one costs 15.00.
    term!(label: "SSI Trailer Physical Damage", weekly: 20.00, from: Date.new(2026, 5, 18))
    term!(label: "SSI Trailer Physical Damage", weekly: 15.00, from: Date.new(2026, 6, 20))

    old_settlement = settlement!(number: "OLD", date: Date.new(2026, 6, 8))
    deduction!(old_settlement, "SSI Trailer Physical Damage", category: "insurance",
               scheduled: 20.00, weekly: 20.00)
    new_settlement = settlement!(number: "NEW", date: Date.new(2026, 7, 31))
    deduction!(new_settlement, "SSI Trailer Physical Damage", category: "insurance",
               scheduled: 20.00, weekly: 20.00)

    findings = audit.findings
    # The 20.00 charge is fine in the old era and excessive in the new one.
    assert_equal 1, findings.size
    assert_equal :excessive_deduction, findings.first.kind
    assert_equal new_settlement, findings.first.settlement
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

  test "a pay line below the agreed rate is flagged" do
    term!(kind: "pay_percentage", label: "Line Haul Pay", percentage: 76)
    settlement!(rate: 0.70.to_d,
                deviation: "Line Haul Pay at 70.0% is below the agreed 76.0%")

    findings = audit.findings
    assert_equal 1, findings.size
    assert_equal :underpaid_percentage, findings.first.kind
    assert_includes findings.first.reason, "below the agreed"
  end

  test "per-line cent rounding is not an underpayment" do
    # A CWT-priced load pays exactly 76% per line to the cent, but the
    # aggregate ratio lands at 75.9997% — the per-line check (pay_deviation
    # nil) is the arbiter, not the aggregate division.
    term!(kind: "pay_percentage", label: "Line Haul Pay", percentage: 76)
    settlement!(rate: "0.75999652".to_d, deviation: nil)

    assert_empty audit.findings
  end

  test "a pay line above the agreed rate is not an underpayment" do
    term!(kind: "pay_percentage", label: "Line Haul Pay", percentage: 76)
    settlement!(rate: 0.85.to_d,
                deviation: "Line Haul Pay at 85.0% is above the agreed 76.0%")

    assert_empty audit.findings
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
