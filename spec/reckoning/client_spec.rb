RSpec.describe Reckoning::Client do
  subject(:client) { described_class.new(connection:) }

  let(:connection) { FakeConnection.new(status, body) }
  let(:status) { 200 }
  let(:body) { {} }

  describe '#run' do
    let(:body) { {'total_paid' => '55830'} }

    it 'posts the facts to the definition and answers its outputs' do
      answer = client.run('sales_commission', {deals: []}, calculation: :year)

      expect(answer.total_paid).to eq(BigDecimal('55830'))
      expect(connection.requests).to eq([[:post, '/definitions/sales_commission/run', {facts: {deals: []}, calculation: :year}]])
    end

    it 'runs the published version a name is pinned to' do
      client.run('sales_commission@3', {})

      expect(connection.requests.last).to eq([:post, '/definitions/sales_commission/run', {facts: {}, version: 3}])
    end

    it 'runs the version asked for, which wins over a pinned name' do
      client.run('sales_commission@3', {}, version: 'draft')

      expect(connection.requests.last.last).to eq(facts: {}, version: 'draft')
    end
  end
end
