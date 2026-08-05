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

  # The lease's stated pay percentages, checked against every rate line.
  AGREED_PERCENTAGES = { "Line Haul Pay" => 76.to_d, "Fuel Surcharge" => 100.to_d }.freeze

  Result = Struct.new(
    :statement_date, :statement_number, :payer, :load_count, :miles,
    :gross_linehaul, :linehaul, :fuel_surcharge, :accessorials, :truck_revenue,
    :total_deductions, :collected_deductions, :balance, :fuel_advance,
    :deductions, :rate_lines, :errors, :ytd_revenue, :ytd_load_count,
    keyword_init: true
  ) do
    def deduction_sum
      deductions.sum { |line| line[:amount] }
    end

    # The statement's own collected figure is the arbiter. Everything found
    # must add up to it, with the fuel advance counted alongside the itemised
    # lines. Collected, not Total: when the week's revenue cannot cover every
    # scheduled deduction the two differ, and only collected money actually
    # left the settlement.
    def accounted_for
      deduction_sum + fuel_advance
    end

    def reconciled?
      errors.empty? && accounted_for == collected_deductions
    end

    def discrepancy
      collected_deductions - accounted_for
    end

    def net_balance
      truck_revenue - accounted_for
    end

    # Rate lines that are pay for something other than the haul itself.
    def accessorial_lines
      rate_lines.reject { |line| AGREED_PERCENTAGES.key?(line[:label]) }
    end

    def realized_linehaul_rate
      return nil unless gross_linehaul.to_d.positive?

      (linehaul / gross_linehaul).round(8)
    end

    def realized_fuel_surcharge_rate
      gross = rate_lines.select { |line| line[:label] == "Fuel Surcharge" }
        .sum(0.to_d) { |line| line[:gross] }
      return nil unless gross.positive?

      (fuel_surcharge / gross).round(8)
    end

    # Exact, line by line: the printed net must be the stated percentage of the
    # printed gross to the cent, and lines with an agreed rate must state it.
    def pay_line_problems
      rate_lines.filter_map do |line|
        expected = (line[:gross] * line[:percentage] / 100).round(2)
        agreed = AGREED_PERCENTAGES[line[:label]]

        if line[:net] != expected
          format("%s pays $%.2f but %s%% of $%.2f is $%.2f",
                 line[:label], line[:net], line[:percentage].to_s("F"), line[:gross], expected)
        elsif agreed && line[:percentage] != agreed
          direction = line[:percentage] < agreed ? "below" : "above"
          format("%s at %s%% is %s the agreed %s%%",
                 line[:label], line[:percentage].to_s("F"), direction, agreed.to_s("F"))
        end
      end
    end
  end

  Line = Struct.new(:label, :amount, :category, :weekly, :balance_target, :detail,
                    :scheduled_amount, :uncollected, :previous_collected,
                    :total_collected_to_date, :new_balance, keyword_init: true)

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
      statement_number: capture(/Statement#:\s+(\S+)/),
      payer: payer,
      load_count: capture(/Load Count:\s*(\d+)/).to_i,
      miles: total_miles,
      gross_linehaul: summary[:gross_linehaul] || 0.to_d,
      **SUMMARY_FIELDS.index_with { |field| summary[field] || 0.to_d }.slice(
        :linehaul, :fuel_surcharge, :accessorials, :truck_revenue,
        :total_deductions, :collected_deductions, :balance
      ),
      fuel_advance: fuel_advance,
      deductions: deduction_lines + trip_permit_lines,
      rate_lines: rate_lines,
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

  PERCENT_TOKEN = /\A(\d+(?:\.\d+)?)\s*%\z/

  # Revenue-section pay lines print gross, a stated percentage, and net:
  #
  #   Line Haul Pay    $6.15 CWT on 42,120 lbs    $2,590.38    76 %    $1,968.69
  #   Stop Off                                      $300.00    76 %      $228.00
  #
  # Columns are separated by runs of spaces; the pricing detail between label
  # and gross (Flat, CWT, MI, or a percentage formula) varies and is skipped.
  def rate_lines
    @rate_lines ||= lines.filter_map do |line|
      tokens = line.split(/\s{2,}/).map(&:strip).reject(&:empty?)
      next if tokens.size < 3

      pct_index = tokens.rindex { |token| token.match?(PERCENT_TOKEN) }
      next if pct_index.nil? || pct_index.zero? || pct_index == tokens.size - 1

      gross = tokens[pct_index - 1][FULL_MONEY, 1]
      net = tokens[pct_index + 1][FULL_MONEY, 1]
      next if gross.nil? || net.nil?

      label = tokens[0...(pct_index - 1)].reverse.find { |token| label_token?(token) }
      next if label.nil?

      { label: label, gross: to_amount(gross),
        percentage: tokens[pct_index][PERCENT_TOKEN, 1].to_d, net: to_amount(net) }
    end
  end

  def label_token?(token)
    return false if token.start_with?("Terminal:")
    return false if token.match?(/\AFlat\z|CWT on|MI on|OF LINE HAUL/i)
    return false if token.match?(FULL_MONEY)

    token.match?(/[A-Za-z]/)
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
        category: category_for(label),
        weekly: weekly,
        balance_target: target,
        **sub_table_after(index, target)
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
        scheduled_amount: amount,
        category: "permits",
        detail: match[:detail].strip
      ).to_h
    end
  end

  # Each block closes with a Total row: the whole amortization line for this
  # deduction, not just the amount collected.
  def sub_table_after(index, target = nil)
    lines[(index + 1)..(index + 12)]&.each do |candidate|
      next unless candidate.start_with?("Total:")

      amounts = candidate.scan(MONEY).flatten.map { |value| to_amount(value) }
      return map_total_row(amounts, target)
    end
    { amount: 0.to_d }
  end

  # The Total row prints two to six figures, and which column each belongs to
  # follows from how many there are plus one piece of arithmetic: the
  # Uncollected column is exactly scheduled minus collected, and blank unless
  # collection fell short. A missing New Balance on a row that does carry
  # running totals is the statement's way of printing zero — the payoff just
  # finished — so it is recorded as 0.00, while a flat weekly line, which has
  # no balance at all, stays nil.
  def map_total_row(found, target = nil)
    scheduled, collected = found.first(2)
    base = { scheduled_amount: scheduled || 0.to_d, amount: collected || 0.to_d,
             uncollected: 0.to_d, previous_collected: 0.to_d, total_collected_to_date: 0.to_d }
    shortfall = scheduled && collected && collected < scheduled ? scheduled - collected : nil

    case found.size
    when 3 then base.merge(uncollected: found[2])
    when 4
      if target && found[2] + found[3] == target
        # The payoff's first collection: no Previous Amount Collected is
        # printed, so the four figures end with what REMAINS — collected so
        # far plus the last figure add up to the header's target. A finished
        # row's four figures end with the target itself instead.
        base.merge(previous_collected: found[2] - found[1],
                   total_collected_to_date: found[2], new_balance: found[3])
      else
        base.merge(previous_collected: found[2], total_collected_to_date: found[3],
                   new_balance: 0.to_d)
      end
    when 5
      if shortfall && found[2] == shortfall
        # Nothing previously collected; the third figure is the shortfall.
        base.merge(uncollected: found[2], total_collected_to_date: found[3],
                   new_balance: found[4])
      else
        base.merge(previous_collected: found[2], total_collected_to_date: found[3],
                   new_balance: found[4])
      end
    when 6 then base.merge(uncollected: found[2], previous_collected: found[3],
                           total_collected_to_date: found[4], new_balance: found[5])
    else base
    end
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
