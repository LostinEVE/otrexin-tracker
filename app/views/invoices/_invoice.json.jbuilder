json.extract! invoice, :id, :invoice_number, :invoice_date, :customer_name, :load_number, :delivery_date, :amount, :product_description, :piece_count, :rate_per_piece, :status, :notes, :created_at, :updated_at
json.url invoice_url(invoice, format: :json)
