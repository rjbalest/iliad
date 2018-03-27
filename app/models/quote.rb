class Quote < ApplicationRecord

  # Constants used by alphavantage.com
  Url = "https://www.alphavantage.co/query"
  ApiKey = "PUDO6FISMN2FU948"
  CompactLength = 100
  OutputFull = "full"
  OutputCompact = "compact"
  Function = "TIME_SERIES_DAILY_ADJUSTED"

  QuandlApiKey = "s3-XT3hM3s41FjrGHUto"

  belongs_to :security

  def self.get(ticker, date)
    quote = find_most_recent(ticker, date)
    if quote.nil? || date - quote.date > 2
      Quote.fetch(ticker)
      quote = find_most_recent(ticker, date)
    end
    quote
  end

  # Find the most recent quote or nil if we have no quotes for given ticker
  def self.find_most_recent(ticker, date=nil)
    date = Date.today if date.nil?
    quote = Quote.where("ticker = ? and date <= ?", ticker, date).order(date: :desc).first
    if quote.nil?
      quote = Quote.where("ticker = ? and date >= ?", ticker, date).order(date: :asc).first
    end
    quote
  end

  # Fetch daily quotes from AlphaAdvantage
  def self.fetch(ticker)

    most_recent=Quote.find_most_recent(ticker)
    outputsize = OutputFull
    unless most_recent.nil?
      unless Date.today - most_recent.date > CompactLength
        outputsize = OutputCompact
      end
    end

    begin
      response = RestClient.get Url,
                                :content_type => :json,
                                :params => {
                                    :function => Function,
                                    :outputsize => outputsize,
                                    :symbol => ticker,
                                    :apikey => ApiKey}
      json = JSON.parse(response)
      ts_data = json["Time Series (Daily)"]

      security = Security.find_or_create_by(:ticker=>ticker)
      quotes = []
      unless ts_data.nil?
        # Select quotes newer than most recent
        ts_data.keys.select{|d| most_recent.nil? || Date.parse(d) > most_recent.date}.each do |date|
          data = ts_data[date]

          quote = Quote.new do |q|
            q.security = security
            q.ticker = ticker
            q.date = date
            q.open = data["1. open"]
            q.high = data["2. high"]
            q.low = data["3. low"]
            q.close = data["4. close"]
            q.adjusted_close = data["5. adjusted close"]
            q.volume = data["6. volume"]
            q.dividend = data["7. dividend amount"]
            q.split_coefficient = data["8. split coefficient"]
          end
          quotes.append quote
          # Use bulk import instead
          #q.save
        end
        Quote.import quotes, :validate => false
      else
        Quote.blacklist(ticker)
      end
    rescue RestClient::ServiceUnavailable
      # Log something here
      print "Service Unavailable: %s" % url
    end
  end

  # Create a quote with null values so that tickers aren't
  # repeatedly fetched if they don't exist.
  def self.blacklist(ticker)
    q = Quote.new do |q|
      q.ticker = ticker
      q.date = Date.today
    end
    q.save
  end

end
