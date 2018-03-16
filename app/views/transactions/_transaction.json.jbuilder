json.extract! transaction, :id, :portfolio, :date, :ticker, :action, :description, :quantity, :price, :fee, :amount, :created_at, :updated_at
json.url transaction_url(transaction, format: :json)
