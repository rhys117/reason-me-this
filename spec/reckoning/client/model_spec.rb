RSpec.describe Reckoning::Client::Model do
  let(:connection) { FakeConnection.new(200, 'total_paid' => '55830') }
  let(:rep_class) do
    Class.new do
      include Reckoning::Client::Model

      attr_reader :deals

      def initialize(deals) = @deals = deals

      reckons :statement, with: 'sales_commission@3', calculation: :year do |year|
        {deals: deals.select { |deal| deal[:closed].year == year }}
      end
    end
  end
  let(:deals) { [{id: 'D1', closed: Date.new(2026, 1, 20)}, {id: 'D0', closed: Date.new(2025, 12, 1)}] }
  let(:rep) { rep_class.new(deals) }

  before { Reckoning::Client.configure { |config| config.connection = connection } }
  after { Reckoning::Client.configure { |config| config.connection = nil } }

  it 'runs the definition on facts the block builds from the instance and the arguments' do
    expect(rep.statement(2026).total_paid).to eq(BigDecimal('55830'))
    expect(connection.requests).to eq([[:post, '/definitions/sales_commission/run',
                                        {facts: {deals: [deals.first]}, calculation: :year, version: 3}]])
  end

  it 'remembers each answer by its arguments' do
    rep.statement(2026)
    rep.statement(2026)
    rep.statement(2025)

    expect(connection.requests.map { |request| request.last[:facts][:deals].map { |deal| deal[:id] } }).to eq([['D1'], ['D0']])
  end

  it 'explains the same run with its steps' do
    connection = FakeConnection.new(200, 'outputs' => {'total_paid' => '55830'}, 'steps' => [])
    Reckoning::Client.configure { |config| config.connection = connection }

    expect(rep.statement_explained(2026).outputs.total_paid).to eq(BigDecimal('55830'))
    expect(connection.requests.last.last).to include(trace: true)
  end

  it 'runs on the client the instance names, for an app with more than one service' do
    other = FakeConnection.new(200, 'total_paid' => '1')
    rep.define_singleton_method(:reckoning_client) { Reckoning::Client.new(connection: other) }

    expect(rep.statement(2026).total_paid).to eq(1)
    expect(connection.requests).to be_empty
  end
end
