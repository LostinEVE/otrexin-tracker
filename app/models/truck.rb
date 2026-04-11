class Truck < ApplicationRecord
  belongs_to :user

  has_many :mileages, dependent: :restrict_with_error
  has_many :fuel_logs, dependent: :restrict_with_error
  has_many :maintenances, dependent: :restrict_with_error
  has_many :expenses, dependent: :restrict_with_error
  has_many :invoices, dependent: :restrict_with_error
  has_many :per_diem_entries, dependent: :restrict_with_error
  has_many :depreciation_assets, dependent: :restrict_with_error

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id }

  scope :active_first, -> { order(active: :desc, name: :asc, created_at: :asc) }

  def display_name
    return name if unit_number.blank?

    "#{unit_number} - #{name}"
  end

  def in_use?
    mileages.exists? || fuel_logs.exists? || maintenances.exists? || expenses.exists? || invoices.exists?
  end
end