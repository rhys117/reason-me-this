RSpec.describe Reckoning::Client do
  let(:connection) { FakeConnection.new(200, 'total' => '2.3') }

  after { described_class.configure { |config| config.connection = nil } }

  it 'runs on the default client, built from the configuration' do
    described_class.configure { |config| config.connection = connection }

    expect(described_class.run('bill@2', {hours: 1}).total).to eq(BigDecimal('2.3'))
    expect(connection.requests).to eq([[:post, '/definitions/bill/run', {facts: {hours: 1}, version: 2}]])
  end

  it 'connects to the configured URL with the configured key' do
    port = closed_port
    described_class.configure do |config|
      config.url = "http://127.0.0.1:#{port}/api"
      config.api_key = 'secret'
    end

    expect { described_class.definitions }.to raise_error(described_class::Unreachable, %r{at http://127\.0\.0\.1:#{port}/api})
  end

  it 'builds a client of its own for a URL and key, for an app with more than one service' do
    port = closed_port

    expect { described_class.new(url: "http://127.0.0.1:#{port}/api", api_key: 'k').publish('bill') }.
      to raise_error(described_class::Unreachable, /#{port}/)
  end
end
