# Finds expenses whose recorded category disagrees with what the vendor and note
# plainly say, plus the handful of entry mistakes that distort a P&L.
#
# Nothing here changes data. It proposes, the driver decides, and the controller
# applies only what was ticked — a guess confidently applied to someone's books
# is worse than no guess at all.
class ExpenseAudit
  # Ordered: the first rule that matches a row wins, so the specific ones
  # ("trailer lease") come before the general ones ("lease").
  RULES = [
    { category: "escrow", patterns: [ /escrow/i ] },
    { category: "eld_dashcam", patterns: [ /\be-?log\b/i, /dash\s*cam/i, /\belectronic log/i ] },
    { category: "phone_internet", patterns: [ /at&t/i, /t-?mobile/i, /verizon/i, /\bcell\b/i, /internet/i, /phone/i ] },
    { category: "towing", patterns: [ /towing/i, /\btow\b/i, /wrecker/i ] },
    { category: "truck_wash_hopper_washout", patterns: [ /wash/i, /blue\s*beacon/i, /truck-?o-?mat/i, /washout/i ] },
    { category: "tolls", patterns: [ /\btoll/i, /turnpike/i, /\bpike\b/i ] },
    { category: "settlement_fee", patterns: [ /\d\s*%/i, /lease (cost|percentage|payment fee)/i, /contract fee/i, /broker fee/i, /dispatch fee/i ] },
    { category: "trailer_lease", patterns: [ /trailer (rent|lease|payment)/i, /trailer.*purchase/i ] },
    { category: "loan_payment", patterns: [ /\bloan\b/i ] },
    { category: "permits", patterns: [ /\bplate/i, /\bpermit/i, /\bifta\b/i, /\bucr\b/i, /\b2290\b/i ] },
    { category: "insurance", patterns: [ /bobtail/i, /occupational accident/i, /physical damage/i, /\bins\.?\b/i, /insurance/i ] },
    { category: "truck_payment", patterns: [ /truck payment/i, /tractor payment/i ] },
    { category: "maintenance", patterns: [
      /\bweld/i, /\btire/i, /\bbrake/i, /\bdrum/i, /\bclutch/i, /turbo/i, /air dryer/i,
      /\bpulley/i, /\bbelt\b/i, /5th wheel/i, /mud flap/i, /oil (change|and lube)/i,
      /\brepair/i, /\bvalve\b/i, /wiper/i, /compressor/i, /exhaust/i, /air (bag|spring)/i
    ] }
  ].freeze

  Finding = Struct.new(:kind, :expense, :suggested_category, :reason, keyword_init: true)

  attr_reader :user

  def initialize(user:)
    @user = user
  end

  def findings
    @findings ||= (unknown_categories + miscategorized + suspicious_amounts + duplicates)
  end

  def any?
    findings.any?
  end

  def grouped
    findings.group_by(&:kind)
  end

  def total_affected
    findings.map { |finding| finding.expense.id }.uniq.size
  end

  # A category string that is not one of the current keys. These come from an
  # older version of the form and show up as their own rows in the P&L
  # breakdown, so the same category never adds together.
  def unknown_categories
    expenses.reject { |expense| Expense::CATEGORIES.key?(expense.category.to_s) }.map do |expense|
      Finding.new(
        kind: :unknown_category,
        expense: expense,
        suggested_category: canonical_for(expense.category),
        reason: "Stored as \"#{expense.category}\", which is not one of the current categories"
      )
    end
  end

  def miscategorized
    expenses.filter_map do |expense|
      next unless Expense::CATEGORIES.key?(expense.category.to_s)

      suggestion = suggest_for(expense)
      next if suggestion.blank? || suggestion == expense.category

      Finding.new(
        kind: :miscategorized,
        expense: expense,
        suggested_category: suggestion,
        reason: "\"#{signal_text(expense).strip.truncate(70)}\" reads like #{Expense.category_label(suggestion)}"
      )
    end
  end

  # A fuel row whose amount is smaller than the gallons it recorded is almost
  # always the price per gallon typed into the amount field.
  def suspicious_amounts
    expenses.filter_map do |expense|
      next unless expense.gallons.to_d.positive?
      next unless expense.amount.to_d.positive?
      next if expense.amount.to_d >= expense.gallons.to_d

      Finding.new(
        kind: :suspicious_amount,
        expense: expense,
        suggested_category: nil,
        reason: "#{ActiveSupport::NumberHelper.number_to_currency(expense.amount)} for " \
                "#{expense.gallons} gallons — looks like a price per gallon in the amount field"
      )
    end
  end

  def duplicates
    expenses.group_by { |expense| [ expense.truck_id, expense.expense_date, expense.amount.to_d.round(0) ] }
      .values
      .select { |group| group.size > 1 }
      .flat_map do |group|
        group.drop(1).map do |expense|
          Finding.new(
            kind: :possible_duplicate,
            expense: expense,
            suggested_category: nil,
            reason: "Same truck, same day, and within a dollar of another entry"
          )
        end
      end
  end

  def self.suggest_for(expense)
    new(user: expense.user).suggest_for(expense)
  end

  def suggest_for(expense)
    text = signal_text(expense)
    return nil if text.blank?

    RULES.each do |rule|
      return rule[:category] if rule[:patterns].any? { |pattern| text.match?(pattern) }
    end
    nil
  end

  private

  def expenses
    @expenses ||= user.expenses.includes(:truck).order(expense_date: :desc).to_a
  end

  def signal_text(expense)
    [ expense.vendor, expense.notes ].compact_blank.join(" ")
  end

  # Maps a legacy label back onto the slug it should have been.
  def canonical_for(raw)
    slug = raw.to_s.downcase.strip.gsub(/[^a-z0-9]+/, "_").squeeze("_").gsub(/\A_|_\z/, "")
    return slug if Expense::CATEGORIES.key?(slug)

    Expense::CATEGORIES.keys.find { |key| Expense.category_label(key).downcase == raw.to_s.downcase } ||
      Expense::CATEGORIES.keys.find { |key| slug.start_with?(key) } ||
      "other"
  end
end
