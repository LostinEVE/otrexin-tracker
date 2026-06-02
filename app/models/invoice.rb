class Invoice < ApplicationRecord
  STATUSES = %w[ unpaid paid ].freeze

  belongs_to :user
  belongs_to :truck

  before_validation :default_status

  validates :invoice_number, :invoice_date, :customer_name, :status, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :piece_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rate_per_piece, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }

  private

  def default_status
    self.status = "unpaid" if status.blank?
  end
end
