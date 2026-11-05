class Rep < ApplicationRecord
  include ReasonMeThis::Model

  has_many :deals, dependent: :destroy
  has_many :quarter_targets, dependent: :destroy
  has_many :quarter_statements, dependent: :destroy

  reasons :statement, with: 'sales_commission', calculation: :year do
    facts do |year|
      {
        deals: deals.closed_in(year).map(&:to_fact),
        cancellations: deals.cancelled_in(year).map(&:to_cancellation),
        quarters: quarter_targets.in(year).map(&:to_fact)
      }
    end
    saves into: :quarter_statements, from: 'by_quarter', by: :start
    keeps_receipts
  end
end
