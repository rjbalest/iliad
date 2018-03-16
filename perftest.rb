
d1 = DateTime.new(2017,1,1)
d2 = DateTime.new(2018,2,27)
p = Portfolio.first
perf = Performance.new(p,d1,d2)


# 2.3.0 :010 > p.positions.collect{|p| p.security.ticker}
# => ["AMZN", "AAPL", "CMG", "DPZ", "FSLR", "HNNMY", "INFN", "LGIH", "FIZZ", "UBNT", "XYL", "GLD"]
# 2.3.0 :011 > p.positions.collect{|p| p.security.ticker}.count
# => 12
# 2.3.0 :012 > perf.brokerage.portfolio.keys
# => ["LGIH", "FIZZ", "UBNT", "FRT", "HNNMY"]
# 2.3.0 :013 > p.positions.collect{|p| p.security.ticker}.count
# => 12
2.3.0 :014 > p.positions.collect{|p| p.security.ticker}
=> ["AMZN", "AAPL", "CMG", "DPZ", "FSLR", "HNNMY", "INFN", "LGIH", "FIZZ", "UBNT", "XYL", "GLD"]
2.3.0 :015 > perf.brokerage.portfolio["LGIH"]
=> #<Investor::Security:0x007f84b2c66590 @ticker="LGIH", @exchange=nil, @history=[[Mon, 06 Feb 2017 00:00:00 UTC +00:00, #<BigDecimal:7f84b2c673a0,'0.1E3',9(18)>, #<BigDecimal:7f84b2c67288,'0.269695E2',18(18)>, #<BigDecimal:7f84b2c67170,'0.695E1',18(18)>, #<BigDecimal:7f84b2c66360,'0.269695E4',18(36)>], [Mon, 07 Aug 2017 00:00:00 UTC +00:00, #<BigDecimal:7f84b3b57798,'-0.1E3',9(27)>, #<BigDecimal:7f84b3b59a98,'0.47631E2',18(18)>, #<BigDecimal:7f84b3b59de0,'0.506E1',18(18)>, #<BigDecimal:7f84b3b57748,'-0.47631E4',18(36)>]], @current_price=nil>
    2.3.0 :016 > lgih = perf.brokerage.portfolio["LGIH"]
=> #<Investor::Security:0x007f84b2c66590 @ticker="LGIH", @exchange=nil, @history=[[Mon, 06 Feb 2017 00:00:00 UTC +00:00, #<BigDecimal:7f84b2c673a0,'0.1E3',9(18)>, #<BigDecimal:7f84b2c67288,'0.269695E2',18(18)>, #<BigDecimal:7f84b2c67170,'0.695E1',18(18)>, #<BigDecimal:7f84b2c66360,'0.269695E4',18(36)>], [Mon, 07 Aug 2017 00:00:00 UTC +00:00, #<BigDecimal:7f84b3b57798,'-0.1E3',9(27)>, #<BigDecimal:7f84b3b59a98,'0.47631E2',18(18)>, #<BigDecimal:7f84b3b59de0,'0.506E1',18(18)>, #<BigDecimal:7f84b3b57748,'-0.47631E4',18(36)>]], @current_price=nil>
    2.3.0 :017 > lgih.history
NoMethodError: undefined method `history' for #<Investor::Security:0x007f84b2c66590>
	from (irb):17
2.3.0 :018 > lgih.shares
 => 0.0
2.3.0 :019 > perf.brokerage.portfolio["LGIH"].shares
 => 0.0
2.3.0 :020 > perf.brokerage.portfolio["LGIH"].basis
 => -2066.1500000000005
2.3.0 :021 > perf.brokerage.portfolio["LGIH"].shares( p.positions_asof )
 => 0.0
2.3.0 :022 > perf.brokerage.portfolio["LGIH"].basis( p.positions_asof )

p.positions.where(:security => Security.where(:ticker=>'LGIH'))