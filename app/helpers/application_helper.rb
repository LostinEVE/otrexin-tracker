module ApplicationHelper
  def expense_category_label(category)
    Expense.category_label(category)
  end

  # Money that is always shown, even when it is zero or nil.
  def money(amount, precision: 2)
    "$#{number_with_precision(amount || 0, precision: precision, delimiter: ",")}"
  end

  # Per-mile figures are absent rather than zero when there are no miles to
  # divide by, so they render as a dash instead of a misleading $0.00.
  def per_mile(amount)
    return "-" if amount.nil?

    "$#{number_with_precision(amount, precision: 3, delimiter: ",")}"
  end

  def profit_class(amount)
    amount.to_d >= 0 ? "text-success" : "text-danger"
  end
end
