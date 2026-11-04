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

  describe 'when the service refuses' do
    {
      [401, {'error' => 'unauthorized'}] => [Reckoning::Client::Unauthorized, 'the service refused the API key'],
      [404, {'error' => 'no definition named bill'}] => [Reckoning::Client::NotFound, 'no definition named bill'],
      [422, {'error' => 'divided by zero in rate'}] => [Reckoning::Client::StepFailed, 'divided by zero in rate'],
      [503, {'error' => 'the run took too long'}] => [Reckoning::Client::Timeout, 'the run took too long'],
      [500, {}] => [Reckoning::Client::Error, 'the service answered HTTP 500']
    }.each do |(code, answer), (error, message)|
      context "with HTTP #{code} #{answer}" do
        let(:status) { code }
        let(:body) { answer }

        it "raises #{error.name.split('::').last}" do
          expect { client.run('bill', {}) }.to raise_error(error, message)
        end
      end
    end

    context 'with problems in the facts' do
      let(:status) { 422 }
      let(:body) { {'problems' => ['hours is missing', 'rate must be a number']} }

      it 'raises InvalidFacts naming each problem' do
        expect { client.run('bill', {}) }.to raise_error(Reckoning::Client::InvalidFacts) do |error|
          expect(error.message).to eq('the facts have problems: hours is missing; rate must be a number')
          expect(error.problems).to eq(['hours is missing', 'rate must be a number'])
        end
      end
    end

    it 'keeps every error under Reckoning::Client::Error' do
      errors = %i[Unauthorized NotFound InvalidFacts StepFailed Timeout Unreachable].map { |name| described_class.const_get(name) }

      expect(errors).to all(be < Reckoning::Client::Error)
    end
  end
end
