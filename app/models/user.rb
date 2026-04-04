class User < ApplicationRecord
	has_secure_password

	has_many :invoices, dependent: :destroy
	has_many :expenses, dependent: :destroy
	has_many :fuel_logs, dependent: :destroy
	has_many :mileages, dependent: :destroy
	has_many :maintenances, dependent: :destroy
	has_many :tax_payments, dependent: :destroy
	has_one :company_profile, dependent: :destroy

	validates :email, presence: true, uniqueness: true
end
