# Turns a parsed settlement statement into a Settlement and its deductions.
#
# Refuses anything that does not reconcile against the statement's own Total
# Deductions figure. A statement read only in part would quietly understate
# costs, which is worse than being told to enter it by hand.
class SettlementImporter
  Outcome = Struct.new(:status, :settlement, :result, :message, keyword_init: true) do
    def imported? = status == :imported
    def skipped?  = status == :skipped
    def failed?   = status == :failed
  end

  attr_reader :user, :truck

  def initialize(user:, truck: nil)
    @user = user
    @truck = truck
  end

  def import(result, filename: nil)
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

    settlement = nil
    ActiveRecord::Base.transaction do
      settlement = create_settlement(result, filename)
      create_expenses(settlement, result)
    end

    Outcome.new(status: :imported, settlement: settlement, result: result,
                message: "#{fmt(result.truck_revenue)} revenue, #{result.deductions.size} deductions.")
  rescue ActiveRecord::RecordInvalid => e
    failure(result, e.record.errors.full_messages.to_sentence)
  end

  # Imports many statements, reporting each one rather than stopping at the
  # first that will not reconcile.
  def import_all(files)
    files.filter_map do |file|
      name = filename_for(file)
      begin
        import(SettlementStatementParser.call(open_for_read(file)), filename: name)
      rescue SettlementStatementParser::ParseError => e
        Outcome.new(status: :failed, result: nil, message: "#{name}: #{e.message}")
      end
    end
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
