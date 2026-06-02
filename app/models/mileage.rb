class Mileage < ApplicationRecord
  belongs_to :user
  belongs_to :truck

  validates :trip_date, :origin, :destination, presence: true
  validates :miles, numericality: { greater_than: 0 }
  validates :revenue, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Revenue per mile for a single trip
  def revenue_per_mile
    return nil unless miles.present? && miles > 0 && revenue.present?
    (revenue.to_f / miles.to_f).round(4)
  end

  # --- Class-level stats ---

  # Total miles across all trips
  def self.total_miles(scope = all)
    scope.sum(:miles).to_f
  end

  # Total revenue across all trips
  def self.total_revenue(scope = all)
    scope.sum(:revenue).to_f
  end

  # Revenue per mile across ALL trips
  def self.overall_revenue_per_mile(scope = all)
    tm = total_miles(scope)
    return nil if tm == 0
    (total_revenue(scope) / tm).round(4)
  end

  # Cost per mile — pulls total expenses from Expense table against total miles
  def self.cost_per_mile(mileage_scope = all, expense_scope: Expense.all)
    tm = total_miles(mileage_scope)
    return nil if tm == 0
    total_expenses = expense_scope.sum(:amount).to_f
    (total_expenses / tm).round(4)
  end
end
