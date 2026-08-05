# Rough federal estimate for a single-filer owner-operator. Reads its money from
# OperatingSummary so the tax page and the P&L can never disagree.
#
# The figures below are single-filer amounts and are not a substitute for a CPA:
# no state tax, no filing status other than single, no credits, no QBI deduction.
class TaxEstimator
  # Verify against the current IRS publications each January before relying on a
  # number here for an actual payment.
  TAX_YEARS = {
    2025 => {
      standard_deduction: 15_750,
      social_security_wage_base: 176_100,
      brackets: [
        [ 11_925, 0.10.to_d ],
        [ 48_475, 0.12.to_d ],
        [ 103_350, 0.22.to_d ],
        [ 197_300, 0.24.to_d ],
        [ 250_525, 0.32.to_d ],
        [ 626_350, 0.35.to_d ],
        [ BigDecimal::INFINITY, 0.37.to_d ]
      ]
    },
    2026 => {
      standard_deduction: 16_100,
      social_security_wage_base: 184_500,
      brackets: [
        [ 12_400, 0.10.to_d ],
        [ 50_400, 0.12.to_d ],
        [ 105_700, 0.22.to_d ],
        [ 201_775, 0.24.to_d ],
        [ 256_225, 0.32.to_d ],
        [ 640_600, 0.35.to_d ],
        [ BigDecimal::INFINITY, 0.37.to_d ]
      ]
    }
  }.freeze

  # Self-employment tax applies to 92.35% of net profit, splits into a Social
  # Security half that stops at the wage base and a Medicare half that does not.
  NET_EARNINGS_FACTOR = 0.9235.to_d
  SOCIAL_SECURITY_RATE = 0.124.to_d
  MEDICARE_RATE = 0.029.to_d

  attr_reader :user, :year, :truck

  def initialize(user:, year:, truck: nil)
    @user = user
    @year = year
    @truck = truck
  end

  def year_start
    Date.new(year, 1, 1)
  end

  def year_end
    Date.new(year, 12, 31)
  end

  def revenue
    summary.revenue.to_d
  end

  def operating_expenses
    summary.expense_total.to_d
  end

  def per_diem_deductions
    summary.per_diem_total.to_d.round(2)
  end

  def depreciation_deductions
    summary.depreciation_total.to_d.round(2)
  end

  def business_profit
    (revenue - operating_expenses - per_diem_deductions - depreciation_deductions).round(2)
  end

  # Net earnings from self-employment: the base the SE tax is actually charged
  # on, not the raw profit.
  def net_earnings_from_self_employment
    [ business_profit * NET_EARNINGS_FACTOR, 0.to_d ].max.round(2)
  end
  alias_method :adjusted_self_employment_income, :net_earnings_from_self_employment

  def self_employment_tax
    earnings = net_earnings_from_self_employment
    return 0.to_d if earnings <= 0

    social_security = [ earnings, social_security_wage_base ].min * SOCIAL_SECURITY_RATE
    medicare = earnings * MEDICARE_RATE

    (social_security + medicare).round(2)
  end

  # Half the SE tax is deductible above the line, then the standard deduction
  # comes off what is left.
  def taxable_income
    [ business_profit - (self_employment_tax / 2) - standard_deduction, 0.to_d ].max.round(2)
  end

  def income_tax
    remaining_income = taxable_income
    previous_limit = 0

    brackets.sum(0.to_d) do |limit, rate|
      next 0.to_d if remaining_income <= previous_limit

      taxable_in_bracket = [ remaining_income - previous_limit, limit - previous_limit ].min
      previous_limit = limit
      taxable_in_bracket * rate
    end.round(2)
  end

  def total_owed
    (self_employment_tax + income_tax).round(2)
  end

  def quarterly_estimate
    (total_owed / 4).round(2)
  end

  def ytd_paid
    user.tax_payments.where(payment_date: year_start..year_end).sum(:amount).to_d.round(2)
  end

  def remaining_balance
    (total_owed - ytd_paid).round(2)
  end

  def standard_deduction
    tax_year_table[:standard_deduction]
  end

  def social_security_wage_base
    tax_year_table[:social_security_wage_base]
  end

  def brackets
    tax_year_table[:brackets]
  end

  # True when the year requested has no published table and the most recent one
  # is standing in for it, so the UI can say so rather than quietly implying the
  # numbers are current.
  def estimated_from_other_year?
    !TAX_YEARS.key?(year)
  end

  def table_year
    TAX_YEARS.key?(year) ? year : TAX_YEARS.keys.max
  end

  private

  def summary
    @summary ||= OperatingSummary.year(user: user, year: year, truck: truck)
  end

  def tax_year_table
    TAX_YEARS.fetch(table_year)
  end
end
