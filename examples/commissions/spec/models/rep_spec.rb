require 'rails_helper'

RSpec.describe Rep do
  let(:rep) do
    load Rails.root.join('db/seeds.rb')
    described_class.find_by!(name: 'Avery Quinn')
  end

  it "works out the year's statement from the rep's deals, cancellations and quarter targets" do
    statement = rep.statement(2026)

    expect(statement.total_paid).to eq(BigDecimal('55830'))
    _method, path, body = service.requests.sole
    expect(path).to eq('/definitions/sales_commission/run')
    expect(body).to include(calculation: :year)
    expect(body[:facts][:deals].map { |deal| deal[:id] }).to eq(%w[D1 D2 D3 D4 D5 D6 D7 D8 D9 D10 D11])
    expect(body[:facts][:deals].second).to eq(id: 'D2', closed: Date.new(2026, 2, 14), total_value: BigDecimal('30000'), years: 1,
                                              discount: BigDecimal('0.25'), kind: 'expansion', share: BigDecimal('0.5'))
    expect(body[:facts][:cancellations]).to eq([{deal: 'D2', on: Date.new(2026, 5, 1)}, {deal: 'D3', on: Date.new(2026, 9, 1)},
                                                {deal: 'D8', on: Date.new(2026, 11, 10)}])
    expect(body[:facts][:quarters].third).to eq(start: Date.new(2026, 7, 1), finish: Date.new(2026, 9, 30),
                                                quota: BigDecimal('120000'), target_incentive: BigDecimal('12000'))
  end

  it 'leaves out the deals and quarters of other years' do
    rep.deals.create!(code: 'D0', closed_on: Date.new(2025, 12, 1), total_value: 1000, kind: 'expansion')

    rep.statement(2026)

    expect(service.requests.sole.last[:facts][:deals].pluck(:id)).not_to include('D0')
  end
end
