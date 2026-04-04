json.extract! fuel_log, :id, :fuel_date, :odometer, :gallons, :price_per_gallon, :total_cost, :location, :station, :notes, :created_at, :updated_at
json.url fuel_log_url(fuel_log, format: :json)
