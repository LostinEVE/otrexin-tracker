class DepreciationAsset < ApplicationRecord
  METHODS = [ "straight_line", "double_declining_balance", "section_179" ].freeze

  belongs_to :user
  belongs_to :truck, optional: true

  validates :name, :asset_type, :placed_in_service_date, :cost_basis, :recovery_period_years, :depreciation_method, presence: true
  validates :cost_basis, numericality: { greater_than: 0 }
  validates :salvage_value, numericality: { greater_than_or_equal_to: 0 }
  validates :recovery_period_years, numericality: { greater_than: 0, only_integer: true }
  validates :depreciation_method, inclusion: { in: METHODS }

  def depreciable_basis
    [ cost_basis.to_d - salvage_value.to_d, 0 ].max
  end

  def annual_deduction
    return 0.to_d if recovery_period_years.to_i <= 0

    case depreciation_method
    when "straight_line"
      (depreciable_basis / recovery_period_years.to_i).round(2)
    when "double_declining_balance"
      (depreciable_basis * (2.0 / recovery_period_years.to_i)).round(2)
    when "section_179"
      depreciable_basis.round(2)
    else
      0.to_d
    end
  end

  def deduction_for_year(year)
    period_start = Date.new(year, 1, 1)
    period_end = Date.new(year, 12, 31)

    deduction_for_period(period_start, period_end)
  end

  def deduction_for_period(period_start, period_end)
    return 0.to_d if period_end < placed_in_service_date

    yearly_schedule.sum do |entry|
      year_start = Date.new(entry[:year], 1, 1)
      year_end = Date.new(entry[:year], 12, 31)
      year_start <= period_end && year_end >= period_start ? entry[:amount] : 0.to_d
    end.round(2)
  end

  def yearly_schedule
    remaining_basis = depreciable_basis
    current_year = placed_in_service_date.year
    final_year = placed_in_service_date.year + recovery_period_years.to_i - 1
    current_basis = depreciable_basis
    schedule = []

    while current_year <= final_year && remaining_basis.positive?
      service_factor = current_year == placed_in_service_date.year ? first_year_service_factor : 1.0
      amount = case depreciation_method
      when "straight_line"
        annual_deduction * service_factor
      when "double_declining_balance"
        current_basis * (2.0 / recovery_period_years.to_i) * service_factor
      when "section_179"
        current_year == placed_in_service_date.year ? remaining_basis : 0.to_d
      else
        0.to_d
      end

      amount = [ amount.to_d.round(2), remaining_basis ].min
      schedule << { year: current_year, amount: amount }
      remaining_basis -= amount
      current_basis = remaining_basis
      current_year += 1
    end

    schedule
  end

  private

  def first_year_service_factor
    months_in_service = 12 - placed_in_service_date.month + 1
    months_in_service / 12.0
  end
end
