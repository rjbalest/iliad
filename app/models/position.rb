require 'csv'
class Position < ApplicationRecord

  belongs_to :portfolio
  belongs_to :security

  def self.import_csv(filename)

    portfolio_name = "default"
    portfolio = nil
    column_headers_valid = false
    date = DateTime.now
    asof_date = nil
    cash = nil

    lines = CSV.read(filename) unless filename.nil?
    lines.each do |line|
      next if line.empty?

      if column_headers_valid

      end

      case line[0]
        when /Positions for account (?<type>Individual|Joint)\s+(?<acct>XXXX-\d+) as of (?<date>.+)/i
          portfolio_name = Regexp.last_match(2)
          asof_date = DateTime.strptime( Regexp.last_match(3), '%H:%M %p %Z, %m/%d/%Y')
          print "Got account %s on %s\n" % [portfolio_name, asof_date.to_s]
          portfolio = Portfolio.find_or_create_by(:name=>portfolio_name,:user_id=>User.current.id)
        when  /Symbol/
          print "Got column header\n"
          # TODO: Validate column header expected keys
          columns_header_valid = true
        when /Account Total/
          print "Got account total\n"
        when /Cash & Money Market/
          cash = line[6].gsub(/[^\d\.-]/,'').to_f
          print "Got cash: %.2f\n" % [cash]
        else
          ticker = line[0]
          description = line[1]
          quantity = line[2]
          basis = line[9].gsub(/[^\d\.-]/,'').to_f
          type = line[15]
          print "Got %d %s for %.2f [%s]\n" % [quantity,ticker,basis,type]
          p = Position.new do |p|
            p.portfolio = portfolio
            p.security = Security.find_or_create_by(:ticker=>ticker)
            p.shares = quantity
            p.asof = asof_date
            p.basis = basis
          end
          p.save
      end
      portfolio.positions_asof = asof_date
      portfolio.save
    end
    portfolio.positions_asof = asof_date
    portfolio.cash = cash
    portfolio.save
  end

end
