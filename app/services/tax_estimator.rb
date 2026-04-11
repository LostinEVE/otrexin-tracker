class TaxEstimator
  FEDERAL_BRACKETS = [
    [11_600, 0.10],
    [47_150, 0.12],
    [100_525, 0.22],
    [191_950, 0.24],
    [Float::INFINITY, 0.32]
  ].freeze
  STANDARD_DEDUCTION = 15_000

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
    invoice_scope.where(status: "paid").where(invoice_date: year_start..year_end).sum(:amount).to_f
  end

  def operating_expenses
    expense_scope.where(expense_date: year_start..year_end).sum(:amount).to_f
  end

  def per_diem_deductions
    per_diem_scope.select { |entry| entry.overlaps_period?(year_start, year_end) }.sum(&:deduction_amount).to_f.round(2)
  end

  def depreciation_deductions
    depreciation_scope.sum { |asset| asset.deduction_for_period(year_start, year_end) }.to_f.round(2)
  end

  def business_profit
    (revenue - operating_expenses - per_diem_deductions - depreciation_deductions).round(2)
  end

  def adjusted_self_employment_income
    [business_profit * 0.9235, 0].max.round(2)
  end

  def self_employment_tax
    [business_profit * 0.153, 0].max.round(2)
  end

  def taxable_income
    [adjusted_self_employment_income - STANDARD_DEDUCTION, 0].max.round(2)
  end

  def income_tax
    remaining_income = taxable_income
    previous_limit = 0

    FEDERAL_BRACKETS.sum do |limit, rate|
      next 0 if remaining_income <= previous_limit

      taxable_in_bracket = [remaining_income - previous_limit, limit - previous_limit].min
      previous_limit = limit
      taxable_in_bracket * rate
    end.round(2)
  end

  def total_owed
    (self_employment_tax + income_tax).round(2)
  end

  def quarterly_estimate
    (total_owed / 4.0).round(2)
  end

  def ytd_paid
    user.tax_payments.where(payment_date: year_start..year_end).sum(:amount).to_f.round(2)
  end

  def remaining_balance
    (total_owed - ytd_paid).round(2)
  end

  private

  def invoice_scope
    scope_by_truck(user.invoices)
  end

  def expense_scope
    scope_by_truck(user.expenses)
  end

  def per_diem_scope
    scope_by_truck(user.per_diem_entries)
  end

  def depreciation_scope
    scope_by_truck(user.depreciation_assets.where('placed_in_service_date <= ?', year_end))
  end

  def scope_by_truck(scope)
    return scope unless truck

    scope.where(truck: truck)
  end
end