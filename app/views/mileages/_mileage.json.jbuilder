json.extract! mileage, :id, :trip_date, :load_number, :origin, :destination, :miles, :revenue, :notes, :created_at, :updated_at
json.url mileage_url(mileage, format: :json)
