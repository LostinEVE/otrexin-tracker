json.extract! tax_payment, :id, :payment_date, :quarter, :amount, :notes, :created_at, :updated_at
json.url tax_payment_url(tax_payment, format: :json)
