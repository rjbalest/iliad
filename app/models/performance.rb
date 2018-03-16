require 'investor'

# Compute the performance of a portfolio over a time range
# Given that we have:
#   All the transactions during that range AND
#   A snapshot of the portfolio at some time within the range of all available transactions, WHICH
#   means the snapshot could be outside the report range.
#
#   The rationale for this approach is that it can be impossible to obtain a complete history of a
#   portfolio for all time.
#
class Performance

  attr_reader :portfolio, :start_date, :end_date
  attr_reader :brokerage

  def initialize(portfolio,start_date_in,end_date_in)
    @portfolio = portfolio
    # Convert to Date in case DateTime
    @start_date = start_date_in.to_date
    @end_date = end_date_in.to_date

    unless start_date < end_date
      raise "Start date [%s] must precede end date [%s]\n" % [start_date, end_date]
    end
    # Assert that we have transactions between start and end date and also up to t_prime,
    # the date of our positions snapshot.
    tx_range = portfolio.transactions_start.to_date..portfolio.transactions_end.to_date
    # Disable these range checks for now.  Should at least set a warning.
    unless tx_range.include? start_date
      #raise "Start date [%s] outside range of known transactions [%s]" % [start_date, tx_range]
    end
    unless tx_range.include? end_date
      #raise "End date [%s] outside range of known transactions [%s]" % [end_date, tx_range]
    end
    unless tx_range.include? portfolio.positions_asof.to_date
      #raise "Positions date [%s] outside range of known transactions [%s]" % [portfolio.positions_asof.to_date, tx_range]
    end

    # Starting cash
    @brokerage = Investor::Brokerage.new(nil, cash_at(start_date))
    init_brokerage

    # Compute time dependent relative scaling factors
    init_spf
  end

  # Compute scaling factors to deal with transfers of money in and out of an account
  # See: http://boards.fool.com/knowledgebase-newly-revised-part-3-32190141.aspx
  def init_spf
    @spf = {}
    transfers = @brokerage.transfers
    value = total_value(start_date)
    relative_value = 100.0

    perf_factor = relative_value / value
    @spf[start_date] = perf_factor

    transfers.keys.each do |date|
      amount = transfers[date]
      value_next = total_value(date)
      relative_value = 100.0 * (value_next - amount) / value
      perf_factor = relative_value / value_next
      value = value_next
      spf[date] = perf_factor
    end
  end

  def init_brokerage
    transactions.each do |tx|
      symbol = tx.security.nil? ? "" : tx.security.ticker
      @brokerage.parse_transaction(tx.date,tx.action,symbol,tx.description,tx.quantity,tx.price,tx.fee,tx.amount)
    end

    # reconcile brokerage transactions to match known position at time t'
    reconcile_positions
  end

  # Get time-dependent scaling factor for relative performance of portfolio
  def spf(date=nil)
    return @spf if date.nil?
    latest = @spf.keys.select{|d| d <= date}.sort.pop
    @spf[latest]
  end

  # Get all transactions needed for this report
  def transactions
    t_prime = portfolio.positions_asof.to_datetime
    start_date_prime = [start_date, t_prime].min
    end_date_prime = [end_date, t_prime].max
    portfolio.transactions.where(date: start_date_prime..end_date_prime)
  end

  # What is the cash at time x
  def cash_at(time_x)
    t_prime = portfolio.positions_asof.to_datetime
    start_date = [time_x, t_prime].min
    end_date = [time_x, t_prime].max

    # This is expected to be 1 or -1
    epsilon = (time_x-t_prime).abs/(time_x-t_prime)

    cash_delta = 0.0
    portfolio.transactions.where(date: start_date..end_date).each do |t|
      cash_delta += t.amount
    end

    cash_t = portfolio.cash + epsilon * cash_delta
  end

  # How many shares of security S were owned at time x
  def shares_at(ticker, time_x)
    t_prime = portfolio.positions_asof.to_datetime
    start_date = [time_x, t_prime].min
    end_date = [time_x, t_prime].max

    # This is expected to be 1 or -1
    epsilon = (time_x-t_prime).abs/(time_x-t_prime)

    share_delta = 0.0
    unless @brokerage.portfolio[ticker].nil?
      share_delta = @brokerage.portfolio[ticker].shares(t_prime)
    end

    shares = 0.0
    position = portfolio.positions.where(:security => Security.where(:ticker=>ticker)).first
    unless position.nil?
      shares = position.shares
    end
    shares_t = shares + epsilon * share_delta
  end

  # How much basis was carried in security S at time x
  def basis_at(ticker, time_x)
    t_prime = portfolio.positions_asof.to_datetime
    start_date = [time_x, t_prime].min
    end_date = [time_x, t_prime].max

    # This is expected to be 1 or -1
    epsilon = (time_x-t_prime).abs/(time_x-t_prime)

    basis_delta = 0.0
    unless @brokerage.portfolio[ticker].nil?
      basis_delta = @brokerage.portfolio[ticker].basis(t_prime)
    end

    basis = 0.0
    position = portfolio.positions.where(:security => Security.where(:ticker=>ticker)).first
    unless position.nil?
      basis = position.basis
    end
    basis_t = basis + epsilon * basis_delta
  end

  # Reconcile start date positions
  # Since we in general are missing the history prior to some date, we create a fake transaction at the start date, such
  # that the existing time series sums to our known position at some time t'.
  # The basis is problematic.  On the one hand, we may have the real basis from our positions data.   On the other hand, for
  # performance, we may not want the real basis, but rather the basis at the starting point of the performance range.
  def reconcile_position(ticker)
      shares = shares_at(ticker, start_date)
      basis = basis_at(ticker, start_date)

      quantity = shares.abs

      # We need a function called basis_at in order to compute the residual basis at start_date, analagous to how we
      # are here computing the residual shares at start_date
      description = "Reconcile position for %s" % ticker

      if basis.nil?
        quote = Investor::Quotes.fetch_quote(ticker, start_date.to_date)
        price = quote["open"].to_f
      else
        price = basis.abs/quantity
      end

      fees = 0
      amount = basis

      unless quantity == 0
        # Create a transaction on the start date of the report
        # technically the action is sell short
        action = shares > 0 ? 'buy' : 'sell'
        @brokerage.parse_trade(start_date,action,ticker,description,quantity,price,fees,amount)
      end
  end

  def reconcile_positions

    # Tickers from transactions
    txkeys = brokerage.portfolio.keys

    # Tickers from Positions
    poskeys = portfolio.positions.collect{|p| p.security.ticker}

    allkeys = poskeys + txkeys
    allkeys.uniq.each do |ticker|
      reconcile_position(ticker)
    end

  end

  def total_value(date)
    portfolio_value = @brokerage.portfolio_value(date)
    cash_value = cash_at(date)
    portfolio_value + cash_value
  end

  def relative_value(date)
    portfolio_value = @brokerage.portfolio_value(date)
    cash_value = cash_at(date)
    spf(date) * (portfolio_value + cash_value)
  end

  def positions_at(time_x)
    p.positions.collect{|p| [p.security.ticker,p.shares]}
  end

  def percentage_change
    relative_value(end_date) - relative_value(start_date)
  end

  def fees
    fees = 0.0
    dates = start_date..end_date
    @brokerage.portfolio.values.each do |security|
      fees += security.fees(dates)
    end
    fees
  end

  def dividends
    dividends = 0.0
    dates = start_date..end_date
    @brokerage.dividends.each do |date,amount|
      if dates.include?(date)
        dividends += amount
      end
    end
    dividends
  end

  def interest
    interest = 0.0
    dates = start_date..end_date
    @brokerage.interest.each do |date,amount|
      if dates.include?(date)
        interest += amount
      end
    end
    interest
  end


  def print_report

    print "Performance from %s to %s\n" % [start_date,end_date]
    print "Relative change in portfolio: %.2f%\n" % percentage_change
    print "Total fees paid: %.2f\n" % fees
    print "Total dividends: %.2f\n" % dividends
    print "Total interest: %.2f\n" % interest

    print "Relative Positions at start date\n"
    print_relative_positions(start_date)

    print "Relative Positions at end date\n"
    print_relative_positions(end_date)
  end

  def print_relative_positions(date)
    # Show relative sizes of positions at start
    print("%10s %10s %10s\n" % ["Position", "Size (%)", "Value"])
    relative_positions(date).each do |p|
      print("%10s %10.2f %10.2f\n" % [p[:ticker], p[:percentage], p[:value]])
    end
  end

  # Return an array of {:ticker, :percent,  :value}
  def relative_positions(date)
    # Show relative sizes of positions at start
    start_value = total_value(date)
    positions = []

    @brokerage.portfolio.values.each do |sec|
      #value = sec.market_value(date)
      shares = sec.shares(date)
      price = sec.price(date)
      basis = sec.basis(date)
      value = shares * price

      pct_value = 100.0 * value.abs / start_value
      positions.append({:ticker => sec.ticker, :percentage => pct_value, :value=>value, :shares=>shares, :basis=>basis, :price=>price})
    end
    sorted_positions = positions.sort{|a,b| b[:percentage] <=> a[:percentage]}

    cash = cash_at(date)
    cash_pct = 100.0 * cash / start_value
    sorted_positions.append({:ticker=>"CASH", :percentage=>cash_pct, :value=>cash, :shares=>cash, :basis=>cash, :price=>cash})
    sorted_positions
  end

end


