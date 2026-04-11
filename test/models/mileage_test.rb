require "test_helper"

class MileageTest < ActiveSupport::TestCase
  test "cost per mile can be calculated for a scoped truck" do
    mileage_scope = Mileage.where(truck: trucks(:one))
    expense_scope = Expense.where(truck: trucks(:one))

    assert_equal 2.0, Mileage.overall_revenue_per_mile(mileage_scope)
    assert_equal 0.44, Mileage.cost_per_mile(mileage_scope, expense_scope: expense_scope)
  end
end
