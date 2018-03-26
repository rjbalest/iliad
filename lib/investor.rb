require 'csv'
require 'yaml'
require 'json'
require 'rest-client'

module Investor

  Debug = true
  Verbose = true

  QuoteServicePort="80"
  QuoteServiceHost="localhost"

  class Quotes
    # Use Yahoo to lookup current prices
    @@registry = []
    @@quotes = nil
    @@quotecache = {}

    def self.market_price(ticker)
      if @@quotes.nil?
        @@quotes = {}
        # Fetch quotes from ticker registry
        fetch_quotes
      end
      unless @@quotes.has_key? ticker
        register(ticker)
        fetch_quotes
      end
      @@quotes[ticker]
    end
    def self.register(ticker)
      puts "Register: %s" % ticker if Debug
      @@registry << ticker unless @@registry.include? ticker
    end
    def self.yql_tickers_in
      clause = ""
      lfirst = true
      @@registry.each do |ticker|
        clause += "," unless lfirst
        lfirst = false
        clause += "\"#{ticker}\""
      end
      clause
    end
    def self.url(ticker,date)
      url = "http://%s/query/%s:%s?date=%s" % [QuoteServiceHost, QuoteServicePort, ticker,date]
      url
    end
    def self.fetch_quote(ticker,date=nil)
      date = Date.today.strftime('%Y-%m-%d') if date.nil?
      key = "%s:%s" % [ticker, date]
      if @@quotecache.has_key? key
        puts "Cache hit on: %s" % key if Debug and Verbose
        return @@quotecache[key]
      else
        puts "Cache miss on: %s" % key if Debug and Verbose
      end
      url = self.url(ticker,date)
      puts "URL: %s" % url if Debug
      begin
        response = RestClient.get url
        hh = JSON.parse(response)
        @@quotecache[key] = hh
      rescue RestClient::NotFound
        hh = nil
      end
    end

    def self.fetch_quotes(date=nil)
      puts "Fetching Quotes for %s" % yql_tickers_in if Debug
      @@registry.each do |ticker|
        hh = self.fetch_quote(ticker,date)
        #ticker = hh["ticker"]
        last_trade_price = hh.nil? ? nil : hh["adjusted_close"].to_f
        @@quotes[ticker] = last_trade_price
        if last_trade_price.nil?
          puts "Warning: No trade price for %s" % ticker
        end
        #puts "%s last trade price : %.2f" % [ticker,last_trade_price.nil? ? 0.0 : last_trade_price]
      end
    end
  end

  # Track the history of a single security
  class Security

    attr_accessor :ticker, :history
    # :current_price
    # attr_reader :shares, :fees

    Date = 0
    Shares = 1
    Price = 2
    Fees = 3
    Basis = 4

    def initialize(ticker,current_price=nil)
      @ticker = ticker
      @exchange = nil
      @history = []
      @avg_price
      @current_price=current_price
    end

    def buy(date,shares,price,fees)
      basis = shares * price
      @history << [date,shares,price,fees,basis]
    end

    def sell(date,shares,price,fees)
      nshares = -1.0 * shares
      basis = nshares * price
      @history << [date,nshares,price,fees,basis]
    end

    def avg_trade_price
      total_shares = 0.0
      total_basis = 0.0
      @history.each do |tx|
        total_shares += tx[Shares].abs
        total_basis += tx[Shares].abs * tx[Price]
      end
      # The average price shares were traded at
      total_basis / total_shares
    end

    def current_price
      if @current_price.nil?
        @current_price = Quotes.market_price(ticker)
        #puts "%s GOT price: %.2f" % [ticker,@current_price]
      end
      if @current_price.nil?
        @current_price = avg_trade_price
      end
      @current_price
    end

    def price(date=nil)
      quote = Quotes.fetch_quote(ticker,date)
      quote.nil? ? nil : quote["adjusted_close"].to_f
    end

    def market_value(date=nil)
      shares(date) * price(date)
    end

    def realized_gain(date=nil)
      net = 0.0
      @history.each do |tx|
        if date.nil? || date >= tx[Date]
          net -= tx[Shares] * tx[Price]
        end
      end
      net
    end

    def realized_or_unrealized_gain(date=nil)
      realized_gain(date) + market_value(date)
    end

    def shares(date=nil)
      shares = 0
      @history.each do |tx|
        if date.nil? || date >= tx[Date]
          shares += tx[Shares].to_f
        end
      end
      shares
    end

    def basis(date=nil)
      basis = 0.0
      @history.each do |tx|
        if date.nil? || date >= tx[Date]
          basis += tx[Basis].to_f
        end
      end
      basis
    end

    # Collect fees over date range
    def fees(dates=nil)
      fees = 0.0
      @history.each do |tx|
        if dates.nil? || dates.include?(tx[Date])
          fees += tx[Fees]
        end
      end
      fees
    end

  end

  class Option < Security
    def initialize(ticker,current_price=nil)
      super(ticker,current_price)
      @option = true
    end
    def current_price
      if @current_price.nil?
        @current_price = avg_trade_price
      end
      @current_price
    end
  end

  class Brokerage

    StartDataLine=2

    attr_accessor :cash, :transfers, :trades, :fees, :interest, :dividends, :neg_dividends, :tax_paid
    attr_reader :portfolio, :perf_factor, :transactions

    def initialize(filename=nil,cash=0.0)
      @txs = CSV.read(filename) unless filename.nil?

      @transfers = {}

      @transfer_amount = 0.0
      @trades = 0
      @fees = 0.0
      @dividends = {}
      @neg_dividends = {}
      @interest = {}
      @tax_paid = {}
      @cash = cash

      @transactions = []
      @portfolio = {}

      @mergers = {}

      recalc_spf

      @ignore = ["EMC"]
    end

    def recalc_spf
      if @cash != 0.0
        @perf_factor = 100.0 / total_value
        puts "Starting value: %.2f" % @cash
        puts "Setting SPF to: %f" % @perf_factor
        puts "Normalized to: %.2f" % (@perf_factor * @cash)
      end
    end

    # Merge a couple of these things into one
    def merge_brokerage(other)
      other.ingest
      @transactions.concat other.transactions
      @cash += other.cash
      recalc_spf
    end

    def print_portfolio
      portfolio_value = total_value
      realized_or_unrealized_gain = 0.0
      puts "Ticker                          Percentage          Shares      Market Value          Realized or Unrealized Gain"
      @portfolio.keys.sort{|a,b| [@portfolio[b].market_value.abs,b] <=> [@portfolio[a].market_value.abs,a]}.each do |ticker|
        sec = @portfolio[ticker]
        percentage = 100.0 * sec.market_value.abs / total_value
        realized_or_unrealized_gain += sec.realized_or_unrealized_gain
        puts "%-30s  %10.2f%%   %10d   %15.2f  %20.2f"  % [ticker, percentage, sec.shares, sec.market_value, sec.realized_or_unrealized_gain]
      end
      percentage = 100.0 * cash.abs / total_value
      puts "%-30s  %10.2f%%   %10d   %15.2f  %20.2f"  % ["CASH", percentage, cash.abs, cash.abs, realized_or_unrealized_gain]
    end

    def total_value
      value = 0.0
      @portfolio.keys.each do |ticker|
        sec = @portfolio[ticker]
        value += sec.market_value
      end
      value += cash
      value
    end

    def portfolio_value(date)
      value = 0.0
      @portfolio.keys.each do |ticker|
        sec = @portfolio[ticker]
        value += sec.market_value(date)
      end
      value
    end

    def relative_value
      total_value * perf_factor
    end

    # convert monetary string to float
    def money_to_f(val)
      val.gsub(/[^\d\.-]/,'').to_f
    end

    def transfer_money(date,amount)
      previous_relative_value = relative_value
      previous_value = total_value
      previous_spf = perf_factor
      # What would I multiply my current balance by to get my current relative value of 105.32
      @cash += amount
      current_value = total_value
      puts "Transferred %.2f at current value of: %.2f and relative valuation: %.2f%%" % [amount, previous_value, previous_relative_value] if Debug
      new_perf_factor = previous_relative_value / current_value
      @perf_factor = new_perf_factor
      puts "Scaled SPF from %.2f to %f" % [previous_spf, perf_factor] if Debug
      puts "Transferred %f at current value of: %.2f and relative valuation: %.2f%%" % [amount, current_value, relative_value] if Debug
    end

    def parse_expiration(date,action,ticker,description,quantity,price,fees,amount)
      puts "Expiring: %s  %.2f" % [ticker,quantity] if Debug
      unless @portfolio.include?(ticker)
        @portfolio[ticker] = Option.new(ticker)
      end
      security = @portfolio[ticker]
      quantity *= 100.0
      security.buy(date,quantity,0.0,0.0)
    end

    def parse_trade(date,action,ticker,description,quantity,price,fees,amount)
      unless @portfolio.include?(ticker)
        @portfolio[ticker] = Security.new(ticker)
        Quotes.register(ticker)
      end
      security = @portfolio[ticker]
      case action
        when /^buy/i
          security.buy(date,quantity,price,fees)
        when /^sell/i
          security.sell(date,quantity,price,fees)
      end
    end

    def parse_split(date,action,ticker,description,quantity,price,fees,amount)
      unless @portfolio.include?(ticker)
        @portfolio[ticker] = Security.new(ticker)
        Quotes.register(ticker)
      end
      security = @portfolio[ticker]
      # Just adjust the # shares with no change to basis
      security.buy(date,quantity,0.0,0.0)
    end

    def parse_cash_in_lieu(date,action,ticker,description,quantity,price,fees,amount)
      @cash += amount
    end

    def parse_merger(date,action,ticker,description,quantity,price,fees,amount)
      puts "Parse Merger"
      unless @mergers.include?(date)
        @mergers[date] = {}
      end
      merger = @mergers[date]
      case description
        when /merger/i
          puts "Merger from %s" % ticker
          merger[:from] = ticker
        else
          puts "Merger to %s" % ticker
          merger[:to] = ticker
          merger[:shares] = quantity
      end
    end

    def parse_options(date,action,ticker,description,quantity,price,fees,amount)
      unless @portfolio.include?(ticker)
        @portfolio[ticker] = Option.new(ticker)
      end
      security = @portfolio[ticker]
      quantity *= 100.0
      case action
        when /^buy/i
          security.buy(date,quantity,price,fees)
        when /^sell/i
          security.sell(date,quantity,price,fees)
      end
    end

    def parse_transaction(date,action,symbol,description,quantity,price,fee,amount)

      case action
        when /dividend/i,/qual div reinvest/i
          @dividends[date] = amount
          @neg_dividends[date] = amount.abs if amount < 0.0
          @cash += amount
        when /interest/i
          @interest[date] = amount
          @cash += amount
        when /tax paid/i
          @tax_paid[date] = amount
          @cash += amount
        when /journaled shares/i
          amount = quantity * price
          parse_trade(date,"buy",symbol,description,quantity,price,0.0,amount)
        when /reinvest shares/i
          parse_trade(date,"buy",symbol,description,quantity,price,0.0,amount)
        when /transfer/i,/journal/i,/funds received/i
          @transfers[date] = amount
          @transfer_amount += amount
          transfer_money(date,amount)
        when /buy to close/i,/buy to open/i,/sell to close/i,/sell to open/i
          parse_options(date,action,symbol,description,quantity,price,fee,amount)
          @fees += fee
          @cash += amount
          @trades += 1
        when /buy/i, /sell/i
          puts "%s: Buy %.2f %s at %.2f" % [date,quantity,symbol,price]
          parse_trade(date,action,symbol,description,quantity,price,fee,amount)
          @fees = fee
          @cash += amount
          @trades += 1
        when /expired/i,/assigned/i
          parse_expiration(date,action,symbol,description,quantity,price,fee,amount)
        when /stock split/i
          parse_split(date,action,symbol,description,quantity,price,fee,amount)
        when /merger/i
          parse_merger(date,action,symbol,description,quantity,price,fee,amount)
        when /cash in lieu/i
          parse_cash_in_lieu(date,action,symbol,description,quantity,price,fee,amount)
        else
          puts "Unrecognized transaction: %s" % description
      end
    end

    def resolve_mergers
      # Assumption is that only one merger happens on the same day
      @mergers.each_pair do |date,merger|
        from = merger[:from]
        to = merger[:to]
        shares = merger[:shares]
        unless @portfolio.include?(from)
          puts "Warning: stock merger on non-existent holding: %s" % from
        else
          puts "Info: stock merger from: %s to: %s" % [from,to]
        end
        sec_from = @portfolio[from]
        unless @portfolio.include?(to)
          @portfolio[to] = Security.new(to)
        end
        sec_to = @portfolio[to]
        price = sec_from.basis / shares.to_f
        sec_to.buy(date, shares, price, sec_from.fees)
        @portfolio.delete(from)
      end
    end

    def ingest
      @txs[StartDataLine..-1].reverse_each do |t|

        datestr = t[0].strip
        txdatestr = datestr.split[0]
        date = Date.strptime(txdatestr, '%m/%d/%Y')

        action = t[1].strip
        symbol = t[2].strip
        description = t[3].strip
        quantity = t[4].strip.to_f
        price = money_to_f(t[5].strip)
        fee = money_to_f(t[6].strip)
        amount = money_to_f(t[7].strip)
        unless @ignore.include? symbol
          @transactions << [date,datestr,action,symbol,description,quantity,price,fee,amount]
        end
      end
    end

    def process
      @transactions.sort{|d| d[0]}.each do |rec|
        parse_transaction(*rec[1..-1])
      end
      resolve_mergers
    end
  end

  class Scottrade < Brokerage

    StartDataLine=1

    # Only need to override the ingest method to deal with the different input data format
    def ingest

      #Symbol,Quantity,Price,ActionNameUS,TradeDate,SettledDate,Interest,Amount,Commission,Fees,CUSIP,Description,TradeNumber,RecordType
      #Cash,0.0000,0.0,Credit Interest,3/31/2017,,0.00,0.26,0.0000,0.0000,,"INT EARNED BANK DEP PROGRAM 31 DAYS @ 0.01% APYE 0.01% AVERAGE CREDIT BALANCE 30,929.01 ",,Financial
      #HBI,0.0000,0.0,Dividend,3/7/2017,,0.00,15.00,0.0000,0.0000,410345102,HANESBRANDS INC COM DIVIDEND ON 100 SHARES OF HBI @ .15000,,Financial
      #HBI,100.0000,19.4975,Buy,2/6/2017,2/9/2017,0.00,-1956.75,-7.0000,0.0000,410345102,Bought 100 Shares of HBI at $19.4975,50000,Trade

      @txs[StartDataLine..-1].reverse_each do |t|

        symbol = t[0].strip
        quantity = t[1].strip.to_f.abs
        price = t[2].strip.to_f
        action = t[3].strip

        datestr = t[4].strip
        txdatestr = datestr.split[0]
        date = Date.strptime(txdatestr, '%m/%d/%Y')

        #  5: settled date
        #  6: interest
        amount = t[7].strip.to_f
        fee = t[8].strip.to_f   # commission
        #  9: fee
        # 10: CUSIP
        description = t[11].strip
        # 12: Trade Number
        # 13: Record Type

        unless @ignore.include? symbol
          @transactions << [date,datestr,action,symbol,description,quantity,price,fee,amount]
        end
      end
    end
  end
end
