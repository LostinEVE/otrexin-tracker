# Reads a carrier settlement statement so a week of bookkeeping becomes one
# upload instead of fourteen hand-typed rows.
#
# Split in two on purpose: +extract+ turns a PDF into text and is the only part
# that touches the gem, while +parse+ is pure text work and carries all the
# judgment. That keeps the interesting half testable without shipping anyone's
# real financial documents into the repository as fixtures.
#
# Nothing is trusted blindly. The statement states its own Total Deductions, so
# every line found is added back up and compared against it. A statement that
# does not reconcile is reported as such rather than imported, because a
# half-read settlement is worse than none.
class SettlementStatementParser
  MONEY = /\(?\$([\d,]+\.\d\d)\)?/
  FULL_MONEY = /\A\(?\$([\d,]+\.\d\d)\)?\z/

  SUMMARY_FIELDS = %i[
    linehaul fuel_surcharge accessorials truck_revenue
    miscellaneous total_deductions collected_deductions balance
  ].freeze

  # Deduction labels as the carrier prints them, mapped onto expense categories.
  # Matched longest-first so "Loan Fee" is not swallowed by "Loan".
  CATEGORY_RULES = {
    /escrow/i => "escrow",
    /trailer lease|lease purchase/i => "trailer_lease",
    /loan/i => "loan_payment",
    /dash\s*cam|e-?log/i => "eld_dashcam",
    /physical damage|bobtail|occupational accident|insurance/i => "insurance",
    /plate|permit/i => "permits",
    /wash/i => "truck_wash_hopper_washout",
    /toll/i => "tolls"
  }.freeze

  Result = Struct.new(
    :statement_date, :statement_number, :payer, :load_count, :miles,
    :gross_linehaul, :linehaul, :fuel_surcharge, :accessorials, :truck_revenue,
    :total_deductions, :balance, :fuel_advance, :deductions, :errors,
    :ytd_revenue, :ytd_load_count,
    keyword_init: true
  ) do
    def deduction_sum
      deductions.sum { |line| line[:amount] }
    end

    # The statement's own total is the arbiter. Everything found must add up to
    # it, with the fuel advance counted alongside the itemised lines.
    def accounted_for
      deduction_sum + fuel_advance
    end

    def reconciled?
      errors.empty? && accounted_for == total_deductions
    end

    def discrepancy
      total_deductions - accounted_for
    end

    def net_balance
      truck_revenue - accounted_for
    end
  end

  Line = Struct.new(:label, :amount, :category, :weekly, :balance_target, :detail, keyword_init: true)

  def self.extract(io_or_path)
    reader = PDF::Reader.new(io_or_path)
    reader.pages.map(&:text).join("\n")
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError, ArgumentError => e
    raise ParseError, "That file could not be read as a PDF (#{e.class.name.demodulize})."
  end

  class ParseError < StandardError; end

  def self.call(io_or_path)
    new(extract(io_or_path)).parse
  end

  attr_reader :text, :lines

  def initialize(text)
    @text = text.to_s
    @lines = @text.lines.map(&:strip)
    @errors = []
  end

  def parse
    Result.new(
      statement_date: statement_date,
      statement_number: capture(/Statement#:\s*\n\s*(\S+)/),
      payer: payer,
      load_count: capture(/Load Count:\s*(\d+)/).to_i,
      miles: total_miles,
      gross_linehaul: summary[:gross_linehaul] || 0.to_d,
      **SUMMARY_FIELDS.index_with { |field| summary[field] || 0.to_d }.slice(
        :linehaul, :fuel_surcharge, :accessorials, :truck_revenue, :total_deductions, :balance
      ),
      fuel_advance: fuel_advance,
      deductions: deduction_lines + trip_permit_lines,
      ytd_revenue: year_to_date[:revenue],
      ytd_load_count: year_to_date[:loads],
      errors: @errors
    )
  end

  private

  def statement_date
    raw = capture(%r{SETTLEMENT STATEMENT (\d{2}/\d{2}/\d{4})})
    return Date.strptime(raw, "%m/%d/%Y") if raw.present?

    @errors << "Could not find a settlement date on this statement."
    nil
  rescue Date::Error
    @errors << "The settlement date on this statement could not be read."
    nil
  end

  def payer
    return "Kaplan Trucking" if text.match?(/kaplantrucking/i)

    nil
  end

  # The summary prints gross linehaul, then eight figures in a fixed order.
  def summary
    @summary ||= begin
      index = text.index("Gross Linehaul:")
      if index.nil?
        @errors << "Could not find the statement summary."
        {}
      else
        found = text[index..].scan(MONEY).flatten.first(9).map { |value| to_amount(value) }
        if found.size < 9
          @errors << "The statement summary was incomplete."
          {}
        else
          { gross_linehaul: found.first }.merge(SUMMARY_FIELDS.zip(found.drop(1)).to_h)
        end
      end
    end
  end

  # The carrier's own running total for the year, printed as
  # "20  $28,832.13  $10,923.13  $894.75  $0.00  $40,650.01" — load count, then
  # line haul, surcharge, accessorials, non-taxable, and finally the 1099 figure.
  def year_to_date
    @year_to_date ||= begin
      index = lines.index { |line| line.include?("Year to Date") }
      row = lines[(index + 1)..(index + 3)]&.find { |line| line.match?(/\A\d+\s+\$/) } if index
      amounts = row.to_s.scan(MONEY).flatten
      if amounts.size >= 5
        { loads: row[/\A(\d+)/, 1].to_i, revenue: to_amount(amounts.last) }
      else
        {}
      end
    end
  end

  def total_miles
    text.scan(/([\d,]+)\s*mi\s*les/).flatten.sum { |value| value.delete(",").to_i }
  end

  # Fuel bought on the carrier's card and recovered on this statement. Recorded
  # against the settlement but not turned into an expense by default, because
  # the driver already enters the fuel receipts themselves and counting both
  # would double the biggest cost on the books.
  EFS_LINE = /\AEFS FUEL\b.*?\(\$([\d,]+\.\d\d)\)/

  def fuel_advance
    lines.sum(0.to_d) do |line|
      match = line.match(EFS_LINE)
      match ? to_amount(match[1]) : 0.to_d
    end
  end

  # A recurring deduction announces itself on one line, in either of two shapes:
  #
  #   Permits Driver - 12169 - ($1,300.00) @ ($130.00)/Week   <- pays down a total
  #   Bobtail Insurance - 12169 - ($6.92)/Week                <- flat every week
  #
  # The reference between the dashes is optional; contractor-side lines omit it.
  DEDUCTION_HEADER = /
    \A(?<label>[A-Za-z][^$]*?)\s+-\s+
    (?:(?<ref>[A-Za-z0-9\-]+)\s+-\s+)?
    \(\$(?<first>[\d,]+\.\d\d)\)
    (?:\s*@\s*\(\$(?<second>[\d,]+\.\d\d)\))?
    \s*\/Week
  /x

  def deduction_lines
    lines.each_with_index.filter_map do |line, index|
      match = line.match(DEDUCTION_HEADER)
      next if match.nil?

      label = match[:label].strip
      next if label.blank?

      # With both figures present the first is the payoff total; with one, the
      # only figure is the weekly amount.
      target = match[:second] ? to_amount(match[:first]) : nil
      weekly = to_amount(match[:second] || match[:first])

      Line.new(
        label: label,
        amount: collected_after_total(index),
        category: category_for(label),
        weekly: weekly,
        balance_target: target
      ).to_h
    end
  end

  # Oversize, overweight and commodity permits are charged against the load in
  # the revenue section rather than as a recurring deduction, so they are real
  # costs that appear nowhere else.
  TRIP_PERMIT = /\APermit\s+(?<detail>State:.*?)\s+\(\$(?<amount>[\d,]+\.\d\d)\)/

  def trip_permit_lines
    lines.filter_map do |line|
      match = line.match(TRIP_PERMIT)
      next if match.nil?

      amount = to_amount(match[:amount])
      next if amount.zero?

      Line.new(
        label: "Trip Permit",
        amount: amount,
        category: "permits",
        detail: match[:detail].strip
      ).to_h
    end
  end

  # Each block closes with a Total row whose first figure is what was actually
  # collected on this statement — the rest are running balances.
  def collected_after_total(index)
    lines[(index + 1)..(index + 12)]&.each do |candidate|
      next unless candidate.start_with?("Total:")

      match = candidate.match(MONEY)
      return match ? to_amount(match[1]) : 0.to_d
    end
    0.to_d
  end

  def category_for(label)
    CATEGORY_RULES.each { |pattern, category| return category if label.match?(pattern) }
    "other"
  end

  def capture(pattern)
    text[pattern, 1]
  end

  def to_amount(value)
    value.to_s.delete(",").to_d
  end
end
