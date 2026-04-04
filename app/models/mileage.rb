class Mileage < ApplicationRecord
  belongs_to :user

  # Revenue per mile for a single trip
  def revenue_per_mile
    return nil unless miles.present? && miles > 0 && revenue.present?
    (revenue.to_f / miles.to_f).round(4)
  end

  # --- Class-level stats ---

  # Total miles across all trips
  def self.total_miles
    sum(:miles).to_f
  end

  # Total revenue across all trips
  def self.total_revenue
    sum(:revenue).to_f
  end

  # Revenue per mile across ALL trips
  def self.overall_revenue_per_mile
    tm = total_miles
    return nil if tm == 0
    (total_revenue / tm).round(4)
  end

  # Cost per mile — pulls total expenses from Expense table against total miles
  def self.cost_per_mile
    tm = total_miles
    return nil if tm == 0
    total_expenses = Expense.sum(:amount).to_f
    (total_expenses / tm).round(4)
  end
end
