class User < ApplicationRecord
	has_secure_password

	has_many :invoices, dependent: :destroy
	has_many :expenses, dependent: :destroy
	has_many :fuel_logs, dependent: :destroy
	has_many :mileages, dependent: :destroy
	has_many :maintenances, dependent: :destroy
	has_many :tax_payments, dependent: :destroy
	has_one :company_profile, dependent: :destroy
	has_many :trucks, dependent: :destroy
	has_many :per_diem_entries, dependent: :destroy
	has_many :depreciation_assets, dependent: :destroy

	validates :email, presence: true, uniqueness: true

	def default_truck
		trucks.order(:created_at).first
	end
end
