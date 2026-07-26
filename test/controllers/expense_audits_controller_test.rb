require "test_helper"

class ExpenseAuditsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "the review screen renders" do
    get expense_audit_url
    assert_response :success
  end

  test "only ticked rows are recategorized" do
    wash = Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 3, 21),
                           category: "fuel", vendor: "Blue Beacon", amount: 117)
    toll = Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 3, 3),
                           category: "fuel", vendor: "Pa Toll plaza", notes: "PA TOLL", amount: 39)

    patch expense_audit_url, params: {
      recategorize: {
        wash.id.to_s => { apply: "1", category: "truck_wash_hopper_washout" },
        toll.id.to_s => { apply: "0", category: "tolls" }
      }
    }

    assert_redirected_to expense_audit_path
    assert_equal "truck_wash_hopper_washout", wash.reload.category
    assert_equal "fuel", toll.reload.category, "an unticked row must be left alone"
  end

  test "a category outside the list is refused" do
    record = Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 3, 1),
                             category: "fuel", vendor: "Pilot", amount: 100)

    patch expense_audit_url, params: {
      recategorize: { record.id.to_s => { apply: "1", category: "not_a_category" } }
    }

    assert_equal "fuel", record.reload.category
  end

  test "ticked duplicates are deleted" do
    keep = Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 2, 22),
                           category: "fuel", vendor: "Petro", amount: 569.48)
    dupe = Expense.create!(user: users(:one), truck: trucks(:one), expense_date: Date.new(2026, 2, 22),
                           category: "fuel", vendor: "Petro", amount: 569.48)

    assert_difference "Expense.count", -1 do
      patch expense_audit_url, params: { delete_ids: [ dupe.id ] }
    end

    assert Expense.exists?(keep.id)
  end

  test "expenses can be moved off a leftover truck" do
    from = trucks(:two)
    to = trucks(:one)
    moved = Expense.where(truck: from).count

    patch expense_audit_url, params: { move_from_truck_id: from.id, move_to_truck_id: to.id }

    assert_operator moved, :>, 0
    assert_equal 0, Expense.where(truck: from).count
  end

  test "another user's expense cannot be touched" do
    other = Expense.create!(user: users(:two), truck: trucks(:three), expense_date: Date.new(2026, 3, 1),
                            category: "fuel", vendor: "Pilot", amount: 100)

    patch expense_audit_url, params: {
      recategorize: { other.id.to_s => { apply: "1", category: "tolls" } },
      delete_ids: [ other.id ]
    }

    assert Expense.exists?(other.id)
    assert_equal "fuel", other.reload.category
  end

  test "another user's truck cannot be a move target" do
    patch expense_audit_url, params: { move_from_truck_id: trucks(:one).id, move_to_truck_id: trucks(:three).id }

    assert_equal users(:one).id, expenses(:one).reload.user_id
    assert_equal trucks(:one).id, expenses(:one).truck_id
  end
end
