require 'csv'
class Transaction < ApplicationRecord

  belongs_to :portfolio
  belongs_to :security, optional: true
  has_one :user, through: :portfolio

  def self.import_csv(filename)

    from_date = nil
    to_date = nil
    asof_date = nil
    portfolio = nil
    transactions = []

    lines = CSV.read(filename) unless filename.nil?
    lines.each do |line|
      next if line.empty?

      case line[0]
        when /[\s\w]+ (?<acct>\w+-\w+) as of (?<asof>[\w\/: ]+) From (?<from>[\d\/]+) to (?<to>[\d\/]+)/i
          portfolio_name = Regexp.last_match(1)
          asof_date = DateTime.strptime( Regexp.last_match(2), '%m/%d/%Y %H:%M:%S %Z')
          from_date = DateTime.strptime( Regexp.last_match(3), '%m/%d/%Y')
          to_date = DateTime.strptime( Regexp.last_match(4), '%m/%d/%Y')
          print "Got Transxs for account %s as of %s\n" % [portfolio_name, asof_date.to_s]
          portfolio = Portfolio.find_or_create_by(:name=>portfolio_name,:user_id=>User.current.id)
        when  /Date/
          print "Got column header\n"
        else

          # TODO: Handle nil portfolio

          datestr = line[0].strip
          txdatestr = datestr.split[0]  # ignore 'as of x/y/z'
          date = Date.strptime(txdatestr, '%m/%d/%Y')

          # Make import idempotent
          unless portfolio.transactions_asof.nil?
            unless date < portfolio.transactions_start or date > portfolio.transactions_end
              print "Skipping transaction for date %s\n" % txdatestr
              next
            end
          end

          action = line[1].strip
          ticker = line[2].strip
          description = line[3].strip
          quantity = line[4].strip.to_f
          price = line[5].strip.gsub(/[^\d\.-]/,'').to_f
          fee = line[6].strip.gsub(/[^\d\.-]/,'').to_f
          amount = line[7].strip.gsub(/[^\d\.-]/,'').to_f
          #next if @ignore.include? symbol
          tx = Transaction.new do |tx|
            tx.portfolio = portfolio
            tx.date = date
            tx.action = action
            tx.security = Security.find_or_create_by(:ticker=>ticker) unless ticker.blank?
            tx.description = description
            tx.quantity = quantity
            tx.price = price
            tx.fee = fee
            tx.amount = amount
          end
          transactions.append tx
          #tx.save
      end
    end
    # Bulk import
    Transaction.import transactions, :validate => false

    # Update portfolio transaction dates
    portfolio.transactions_asof = asof_date
    if portfolio.transactions_start.nil? or from_date < portfolio.transactions_start
      portfolio.transactions_start = from_date
    end
    if portfolio.transactions_end.nil? or to_date > portfolio.transactions_end
      portfolio.transactions_end = to_date
    end
    portfolio.save
    portfolio
  end

end
