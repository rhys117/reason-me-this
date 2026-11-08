RSpec.describe ReasonMeThis::Client do
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

    it 'runs the version in effect on a day' do
      client.run('sales_commission', {}, on: Date.new(2026, 7, 1))

      expect(connection.requests.last.last).to eq(facts: {}, on: Date.new(2026, 7, 1))
    end

    it 'runs the version asked for, which wins over a pinned name' do
      client.run('sales_commission@3', {}, version: 'draft')

      expect(connection.requests.last.last).to eq(facts: {}, version: 'draft')
    end
  end

  describe '#explain' do
    let(:body) { {'outputs' => {'total' => '2.3'}, 'steps' => [{'step' => 'total', 'value' => '2.3'}], 'version' => 3} }

    it 'runs with a trace and answers the outputs with the steps that made them' do
      explained = client.explain('bill', {hours: 2}, calculation: :invoice)

      expect(explained.outputs.total).to eq(BigDecimal('2.3'))
      expect(explained.steps).to eq([{step: 'total', value: BigDecimal('2.3')}])
      expect(connection.requests.last.last).to eq(facts: {hours: 2}, calculation: :invoice, trace: true)
    end

    it 'says which version ran' do
      expect(client.explain('bill', {hours: 2}).version).to eq(3)
    end

    it 'has no events when the service lists none' do
      expect(client.explain('bill', {hours: 2}).events).to eq([])
    end

    context 'when the answer set off events' do
      let(:body) { {'outputs' => {'total' => '120.5'}, 'steps' => [], 'events' => [{'name' => 'over_limit', 'data' => {'over_by' => '20.5'}}]} }

      it 'reads each event by name, with exact values' do
        expect(client.explain('bill', {hours: 2}).events).to eq([ReasonMeThis::Event.new(name: :over_limit, data: {over_by: BigDecimal('20.5')})])
      end
    end
  end

  describe '#push' do
    let(:body) { {'problems' => [], 'passed' => 2, 'failed' => 0, 'cases' => []} }

    it 'saves the draft and answers its report' do
      report = client.push('bill', yaml: 'calculations: {}', cases: '[]')

      expect(report).to eq(problems: [], passed: 2, failed: 0, cases: [])
      expect(connection.requests).to eq([[:put, '/definitions/bill', {yaml: 'calculations: {}', cases: '[]'}]])
    end

    it 'sends no cases when none are given' do
      client.push('bill', yaml: 'calculations: {}')

      expect(connection.requests.last.last).to eq(yaml: 'calculations: {}', cases: '')
    end

    context 'when the draft has problems' do
      let(:status) { 422 }
      let(:body) { {'problems' => ['calculations is missing']} }

      it 'raises Rejected with the report' do
        expect { client.push('bill', yaml: '') }.to raise_error(ReasonMeThis::Rejected) do |error|
          expect(error.message).to eq('the definition was not accepted: calculations is missing')
          expect(error.report).to eq(problems: ['calculations is missing'])
        end
      end
    end
  end

  describe '#publish' do
    let(:status) { 201 }
    let(:body) { {'version' => 4} }

    it 'publishes the draft and answers its version number' do
      expect(client.publish('bill')).to eq(4)
      expect(connection.requests).to eq([[:post, '/definitions/bill/publish', nil]])
    end

    context 'when a case fails' do
      let(:status) { 422 }
      let(:body) { {'problems' => [], 'passed' => 1, 'failed' => 2, 'cases' => []} }

      it 'raises Rejected saying how many cases failed' do
        expect { client.publish('bill') }.to raise_error(ReasonMeThis::Rejected, 'the definition was not accepted: 2 cases failed')
      end
    end
  end

  describe '#definitions' do
    let(:body) { {'definitions' => [{'name' => 'bill', 'published_version' => 3, 'updated_at' => '2026-11-04T10:00:00Z'}]} }

    it 'lists the definitions on the service' do
      expect(client.definitions).to eq([{name: 'bill', published_version: 3, updated_at: '2026-11-04T10:00:00Z'}])
      expect(connection.requests).to eq([[:get, '/definitions', nil]])
    end
  end

  describe '#definition' do
    let(:body) { {'name' => 'bill', 'yaml' => 'calculations: {}', 'cases' => '[]', 'published_version' => 3} }

    it 'reads one definition with its draft and cases' do
      expect(client.definition('bill')).to eq(name: 'bill', yaml: 'calculations: {}', cases: '[]', published_version: 3)
      expect(connection.requests).to eq([[:get, '/definitions/bill', nil]])
    end
  end

  describe 'when the service refuses' do
    {
      [401, {'error' => 'unauthorized'}] => [ReasonMeThis::Unauthorized, 'the service refused the API key'],
      [404, {'error' => 'no definition named bill'}] => [ReasonMeThis::NotFound, 'no definition named bill'],
      [422, {'error' => 'divided by zero in rate'}] => [ReasonMeThis::StepFailed, 'divided by zero in rate'],
      [503, {'error' => 'the run took too long'}] => [ReasonMeThis::Timeout, 'the run took too long'],
      [500, {}] => [ReasonMeThis::Error, 'the service answered HTTP 500']
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
        expect { client.run('bill', {}) }.to raise_error(ReasonMeThis::InvalidFacts) do |error|
          expect(error.message).to eq('the facts have problems: hours is missing; rate must be a number')
          expect(error.problems).to eq(['hours is missing', 'rate must be a number'])
        end
      end
    end

    it 'keeps every error under ReasonMeThis::Error' do
      errors = %i[Unauthorized NotFound InvalidFacts StepFailed Timeout Unreachable].map { |name| ReasonMeThis.const_get(name) }

      expect(errors).to all(be < ReasonMeThis::Error)
    end
  end
end
