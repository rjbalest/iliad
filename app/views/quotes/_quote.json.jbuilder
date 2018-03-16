json.extract! quote, :id, :ticker, :date, :open, :high, :low, :close, :adjusted_close, :volume, :dividend, :split_coefficient, :created_at, :updated_at
json.url quote_url(quote, format: :json)
