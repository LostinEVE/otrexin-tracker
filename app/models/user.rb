class User < ApplicationRecord
  has_secure_password

  has_many :invoices, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :settlement_templates, dependent: :destroy
  has_many :settlements, dependent: :destroy
  has_many :escrow_ledger_entries, dependent: :destroy
  has_many :fuel_logs, dependent: :destroy
  has_many :maintenances, dependent: :destroy
  has_many :tax_payments, dependent: :destroy
  has_one :company_profile, dependent: :destroy
  has_many :trucks, dependent: :destroy
  has_many :per_diem_entries, dependent: :destroy
  has_many :depreciation_assets, dependent: :destroy

  before_validation :normalize_email

  validates :email,
    presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { case_sensitive: false }

  def default_truck
    trucks.order(:created_at).first
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
