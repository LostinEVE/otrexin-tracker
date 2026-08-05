# A flagged settlement the driver has looked at and accepted stops warning;
# the acknowledgment is a timestamp so the record shows when it happened.
class AddReviewedAtToSettlements < ActiveRecord::Migration[8.1]
  def change
    add_column :settlements, :reviewed_at, :datetime
  end
end
