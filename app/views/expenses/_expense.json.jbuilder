json.extract! expense, :id, :expense_date, :category, :vendor, :amount, :notes, :created_at, :updated_at
json.url expense_url(expense, format: :json)
