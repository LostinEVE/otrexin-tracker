require_relative 'config/environment'

user = User.first
user.fuel_logs.where('odometer > 100000').order(odometer: :desc).each do |log|
  puts "Truck: #{log.truck&.display_name}, Date: #{log.created_at.to_date}, Odometer: #{log.odometer}"
end
