class Portfolio < ApplicationRecord

  belongs_to :user
  has_many :positions, dependent: :destroy
  has_many :transactions, dependent: :destroy

  before_create :init_label

  def init_label
    if label.nil?
      self.label = name
    end
  end

  def watched_positions

    # Construct a report
    return positions if positions.empty?

    d1 = self.positions_asof
    #d2 = self.transactions_end
    d2 = Date.today
    @performance = Performance.new(self,d1,d2)
    today = Date.today
    positions = @performance.relative_positions(today)
    positions
  end

end
