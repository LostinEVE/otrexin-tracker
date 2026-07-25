require "test_helper"

class PerDiemEntryTest < ActiveSupport::TestCase
  test "an entry fully inside the period deducts in full" do
    entry = per_diem_entries(:one)

    assert_equal 1_050.to_d, entry.deduction_for_period(Date.new(2026, 1, 1), Date.new(2026, 12, 31))
  end

  test "an entry outside the period deducts nothing" do
    entry = per_diem_entries(:one)

    assert_equal 0.to_d, entry.deduction_for_period(Date.new(2026, 4, 1), Date.new(2026, 4, 30))
  end

  test "a trip straddling year end splits across both years instead of counting twice" do
    entry = PerDiemEntry.create!(
      user: users(:one),
      truck: trucks(:one),
      start_date: Date.new(2025, 12, 28),
      end_date: Date.new(2026, 1, 3),
      qualifying_days: 7,
      daily_rate: 80
    )

    first_year = entry.deduction_for_period(Date.new(2025, 1, 1), Date.new(2025, 12, 31))
    second_year = entry.deduction_for_period(Date.new(2026, 1, 1), Date.new(2026, 12, 31))

    assert_equal 320.to_d, first_year
    assert_equal 240.to_d, second_year
    assert_equal entry.deduction_amount, first_year + second_year
  end

  test "a partial period claims only its share of the qualifying days" do
    entry = per_diem_entries(:one)

    # Three of the trip's seven days fall inside the window.
    assert_equal 450.to_d, entry.deduction_for_period(Date.new(2026, 3, 1), Date.new(2026, 3, 3))
  end
end
