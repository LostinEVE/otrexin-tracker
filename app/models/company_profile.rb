class CompanyProfile < ApplicationRecord
	belongs_to :user

	def city_state_zip
		[city, state, zip].reject(&:blank?).join(", ")
	end

	def contact_line
		parts = []
		parts << "Phone: #{phone}" if phone.present?
		parts << "Email: #{email}" if email.present?
		parts << "DOT: #{dot_number}" if dot_number.present?
		parts << "MC: #{mc_number}" if mc_number.present?
		parts.join(" | ")
	end
end
