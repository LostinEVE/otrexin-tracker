json.extract! maintenance, :id, :maintenance_date, :maintenance_type, :cost, :odometer, :vendor, :notes, :created_at, :updated_at
json.url maintenance_url(maintenance, format: :json)
