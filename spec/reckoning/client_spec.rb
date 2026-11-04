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
  end
end
