# One authorized item from the lease: a permitted deduction (by printed label
# or by category), an escrow with its target, or an agreed pay percentage.
class LeaseTerm < ApplicationRecord
  KINDS = %w[ deduction escrow pay_percentage ].freeze

  belongs_to :user

  validates :kind, inclusion: { in: KINDS }
  validates :percentage, presence: true, if: -> { kind == "pay_percentage" }
  validate :label_or_category_present, if: -> { kind != "pay_percentage" }

  private

  def label_or_category_present
    errors.add(:base, "needs a label or a category") if label.blank? && category.blank?
  end
end
