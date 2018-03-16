class Portfolio < ApplicationRecord

  belongs_to :user
  has_many :positions
  has_many :transactions

  before_create :init_label

  def init_label
    self.label = name
  end

  def watched_positions

    # Construct a report
    d1 = self.positions_asof
    d2 = self.transactions_end
    @performance = Performance.new(self,d1,d2)
    today = Date.today
    positions = @performance.relative_positions(today)
    positions
  end

end
