# Turns a parsed settlement statement into a Settlement and its deductions.
#
# Refuses anything that does not reconcile against the statement's own Total
# Deductions figure. A statement read only in part would quietly understate
# costs, which is worse than being told to enter it by hand.
class SettlementImporter
  # A driver who has been entering settlements by hand already has those
  # deductions on the books. Importing the same statement would record them a
  # second time, so an overlap is detected and the statement held back unless
  # the hand-typed rows are explicitly replaced.
  #
  # Matched on amount within a few days rather than on the exact date, because a
  # statement dated the 8th is often typed up on the 9th.
  CONFLICT_WINDOW = 3
  CONFLICT_THRESHOLD = 3

  Outcome = Struct.new(:status, :settlement, :result, :message, :conflicts, keyword_init: true) do
    def imported?  = status == :imported
    def skipped?   = status == :skipped
    def failed?    = status == :failed
    def conflict?  = status == :conflict
  end

  attr_reader :user, :truck

  def initialize(user:, truck: nil)
    @user = user
    @truck = truck
  end

  def import(result, filename: nil, replace_existing: false)
    return failure(result, "No settlement date could be read.") if result.statement_date.blank?
    return failure(result, result.errors.to_sentence) if result.errors.any?

    unless result.reconciled?
      return failure(result, "Deductions add to #{fmt(result.accounted_for)} but the statement " \
                             "says #{fmt(result.total_deductions)} — off by #{fmt(result.discrepancy.abs)}.")
    end

    existing = duplicate_of(result)
    if existing
      return Outcome.new(status: :skipped, settlement: existing, result: result,
                         message: "Already imported (#{existing.statement_date}).")
    end

    clashing = conflicting_expenses(result)
    if clashing.size >= CONFLICT_THRESHOLD && !replace_existing
      return Outcome.new(
        status: :conflict, result: result, conflicts: clashing,
        message: "#{clashing.size} expenses around #{result.statement_date} look like this " \
                 "settlement already entered by hand (#{fmt(clashing.sum(&:amount))}). Nothing imported."
      )
    end

    settlement = nil
    removed = 0
    ActiveRecord::Base.transaction do
      removed = clashing.each(&:destroy!).size if replace_existing && clashing.any?
      settlement = create_settlement(result, filename)
      create_expenses(settlement, result)
    end

    note = removed.positive? ? " Replaced #{removed} hand-entered rows." : ""
    Outcome.new(status: :imported, settlement: settlement, result: result,
                message: "#{fmt(result.truck_revenue)} revenue, #{result.deductions.size} deductions.#{note}")
  rescue ActiveRecord::RecordInvalid => e
    failure(result, e.record.errors.full_messages.to_sentence)
  end

  # Imports many statements, reporting each one rather than stopping at the
  # first that will not reconcile.
  def import_all(files, replace_existing: false)
    files.filter_map do |file|
      name = filename_for(file)
      begin
        import(SettlementStatementParser.call(open_for_read(file)),
               filename: name, replace_existing: replace_existing)
      rescue SettlementStatementParser::ParseError => e
        Outcome.new(status: :failed, result: nil, message: "#{name}: #{e.message}")
      end
    end
  end

  # Expenses that are not tied to any settlement but match this statement's
  # deduction amounts around its date — the signature of the same money already
  # recorded by hand.
  def conflicting_expenses(result)
    amounts = result.deductions.map { |line| line[:amount].to_d }.select(&:positive?).uniq
    return [] if amounts.size < CONFLICT_THRESHOLD

    scope = user.expenses.where(settlement_id: nil, amount: amounts)
      .where(expense_date: (result.statement_date - CONFLICT_WINDOW)..(result.statement_date + CONFLICT_WINDOW))
    scope = scope.where(truck: truck) if truck
    scope.to_a
  end

  private

  def create_settlement(result, filename)
    user.settlements.create!(
      truck: truck,
      statement_date: result.statement_date,
      statement_number: result.statement_number,
      payer: result.payer,
      load_count: result.load_count,
      gross_linehaul: result.gross_linehaul,
      linehaul: result.linehaul,
      fuel_surcharge: result.fuel_surcharge,
      accessorials: result.accessorials,
      fuel_advance: result.fuel_advance,
      source_filename: filename,
      notes: result.miles.positive? ? "#{ActiveSupport::NumberHelper.number_to_delimited(result.miles)} paid miles" : nil
    )
  end

  def create_expenses(settlement, result)
    result.deductions.each do |line|
      next unless line[:amount].to_d.positive?

      user.expenses.create!(
        truck: truck,
        settlement: settlement,
        expense_date: result.statement_date,
        category: line[:category],
        vendor: result.payer,
        amount: line[:amount],
        notes: [ line[:label], line[:detail] ].compact_blank.join(" — ")
      )
    end
  end

  def duplicate_of(result)
    if result.statement_number.present?
      user.settlements.find_by(statement_number: result.statement_number)
    else
      user.settlements.find_by(statement_date: result.statement_date)
    end
  end

  def failure(result, message)
    Outcome.new(status: :failed, result: result, message: message)
  end

  def filename_for(file)
    return File.basename(file) if file.is_a?(String)

    file.try(:original_filename) || file.try(:path)&.then { |p| File.basename(p) }
  end

  def open_for_read(file)
    file.is_a?(String) ? file : file.tap { |f| f.rewind if f.respond_to?(:rewind) }
  end

  def fmt(amount)
    ActiveSupport::NumberHelper.number_to_currency(amount)
  end
end
