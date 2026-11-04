class Rep < ApplicationRecord
  include Reckoning::Client::Model

  has_many :deals, dependent: :destroy
  has_many :quarter_targets, dependent: :destroy

  reckons :statement, with: 'sales_commission', calculation: :year do |year|
    {
      deals: deals.closed_in(year).map(&:to_fact),
      cancellations: deals.cancelled_in(year).map(&:to_cancellation),
      quarters: quarter_targets.in(year).map(&:to_fact)
    }
  end
end
