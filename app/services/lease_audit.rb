# Checks every settlement deduction, escrow entry, and realized pay rate
# against the lease terms on file, in the same propose-don't-decide shape as
# ExpenseAudit.
#
# 49 CFR Part 376 requires the lease to specify permitted deductions and gives
# a percentage-paid lessee the right to see the rating basis for settlements.
# A flag here means "review this line against the lease" and cites the
# settlement and line. It never states a legal conclusion.
class LeaseAudit
  DISCLAIMER = "Informational review of settlement lines against the lease terms you entered. " \
               "This is not legal advice.".freeze

  Finding = Struct.new(:kind, :settlement, :label, :reason, keyword_init: true)

  attr_reader :user

  def initialize(user:)
    @user = user
  end

  def findings
    @findings ||= unauthorized_deductions + excessive_deductions +
                  escrow_over_target + underpaid_percentages
  end

  def any?
    findings.any?
  end

  def grouped
    findings.group_by(&:kind)
  end

  # Marks each settlement_deduction with whether an authorized term matched.
  # The only writing this audit ever does, and it records a matching fact,
  # not a judgment.
  def annotate!
    deductions.each do |deduction|
      deduction.update!(lease_authorized: term_for(deduction).present?)
    end
  end

  def unauthorized_deductions
    deductions.filter_map do |deduction|
      next if term_for(deduction)

      Finding.new(
        kind: :unauthorized_deduction,
        settlement: deduction.settlement,
        label: deduction.label,
        reason: "\"#{deduction.label}\" on the #{cite(deduction.settlement)} statement has no " \
                "matching term in the lease on file — review it against the lease."
      )
    end
  end

  def excessive_deductions
    deductions.filter_map do |deduction|
      term = term_for(deduction)
      next if term.nil? || term.weekly_amount.blank? || deduction.scheduled_amount.blank?
      next unless deduction.scheduled_amount > term.weekly_amount

      Finding.new(
        kind: :excessive_deduction,
        settlement: deduction.settlement,
        label: deduction.label,
        reason: "\"#{deduction.label}\" on the #{cite(deduction.settlement)} statement is " \
                "#{money(deduction.scheduled_amount)} against the lease's stated " \
                "#{money(term.weekly_amount)}/week — review it against the lease."
      )
    end
  end

  # Escrow deposits are the only escrow movement on a settlement, so the check
  # available is whether more is being held than the lease says to collect.
  def escrow_over_target
    escrow_entries.filter_map do |entry|
      term = escrow_term_for(entry)
      target = term&.balance_target
      next if target.blank?
      next unless entry.running_balance > target

      Finding.new(
        kind: :escrow_over_target,
        settlement: entry.settlement,
        label: entry.name,
        reason: "\"#{entry.name}\" holds #{money(entry.running_balance)} against the lease's " \
                "#{money(target)} target on the #{cite(entry.settlement)} statement — " \
                "review it against the lease."
      )
    end
  end

  # The aggregate linehaul-to-gross ratio is noisy: CWT-priced loads round to
  # the cent per line, so a fully compliant statement lands at 75.9997%. The
  # parser's per-line check is exact and is the arbiter here — a settlement is
  # underpaid when a pay line's stated rate sits below the agreed one.
  def underpaid_percentages
    settlements.filter_map do |settlement|
      next if settlement.pay_deviation.blank?
      next unless settlement.pay_deviation.match?(/below the agreed/)

      Finding.new(
        kind: :underpaid_percentage,
        settlement: settlement,
        label: "Line Haul Pay",
        reason: "The #{cite(settlement)} statement reports: #{settlement.pay_deviation} — " \
                "review it against the lease."
      )
    end
  end

  private

  def settlements
    @settlements ||= user.settlements.includes(:settlement_deductions, :escrow_ledger_entries).to_a
  end

  def deductions
    settlements.flat_map(&:settlement_deductions)
  end

  def escrow_entries
    settlements.flat_map(&:escrow_ledger_entries)
  end

  def terms
    @terms ||= user.lease_terms.to_a
  end

  # Terms in force on a given date: an effective_from in the future doesn't
  # apply yet, and among competing terms the most recent one wins — a
  # superseded term judges only the settlements of its own era.
  def applicable(candidates, date)
    candidates
      .select { |term| term.effective_from.nil? || (date && term.effective_from <= date) }
      .max_by { |term| term.effective_from || Date.new(1, 1, 1) }
  end

  # A term authorizes a deduction when its label matches the printed label, or
  # when it names no label and covers the whole category. Escrow lines appear
  # in the deduction detail too, so escrow-kind terms authorize them as well.
  def term_for(deduction)
    date = deduction.settlement&.statement_date
    by_label = terms.select do |term|
      %w[ deduction escrow ].include?(term.kind) && term.label&.casecmp?(deduction.label)
    end
    by_category = terms.select do |term|
      term.kind == "deduction" && term.label.blank? && term.category == deduction.category
    end
    applicable(by_label, date) || applicable(by_category, date)
  end

  def escrow_term_for(entry)
    candidates = terms.select { |term| term.kind == "escrow" && term.label&.casecmp?(entry.name) }
    applicable(candidates, entry.settlement&.statement_date || entry.entry_date)
  end

  def cite(settlement)
    settlement.statement_number.presence || settlement.statement_date.to_s
  end

  def money(amount)
    ActiveSupport::NumberHelper.number_to_currency(amount)
  end
end
