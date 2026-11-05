require 'rails_helper'

RSpec.describe 'Saving a rep statement' do
  let(:service) { CannedService::Connection.new(JSON.parse(Rails.root.join('spec/fixtures/full_year_trace.json').read)) }

  it "writes each quarter of the year into the rep's quarter statements, and keeps a receipt" do
    post rep_statement_path(rep, year: 2026)

    expect(rep.quarter_statements.order(:start).pluck(:start, :payout)).to eq(
      [[Date.new(2026, 1, 1), 5000], [Date.new(2026, 4, 1), 8250], [Date.new(2026, 7, 1), 11_580], [Date.new(2026, 10, 1), 31_000]]
    )
    expect(rep.reason_me_this_receipts.sole).to have_attributes(reasoning: 'statement', blueprint: 'sales_commission', version: '1')
    expect(service.requests.last.last).to include(trace: true)
  end

  it 'updates the same quarters when saved again, and keeps a receipt each time' do
    2.times { post rep_statement_path(rep, year: 2026) }

    expect([rep.quarter_statements.count, rep.reason_me_this_receipts.count]).to eq([4, 2])
  end
end
