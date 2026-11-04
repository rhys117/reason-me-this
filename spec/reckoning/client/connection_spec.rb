require 'socket'

RSpec.describe Reckoning::Client::Connection do
  def serve(status, body)
    server = TCPServer.new('127.0.0.1', 0)
    received = Queue.new
    Thread.new do
      client = server.accept
      head = +''
      head << client.gets until head.end_with?("\r\n\r\n")
      received << [head, client.read(head[/Content-Length: (\d+)/i, 1].to_i)]
      client.write("HTTP/1.1 #{status} OK\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
      client.close
    end
    [server.addr[1], received]
  end

  it 'sends the key and JSON, keeps decimals exact and dates ISO on the wire, and reads the JSON answer' do
    port, received = serve(200, '{"total":"2.3"}')
    facts = {rate: BigDecimal('0.1'), hours: BigDecimal('1.10'), on: Date.new(2026, 7, 1), at: Time.utc(2026, 7, 1, 9, 30)}

    answer = described_class.new("http://127.0.0.1:#{port}/api/", 'secret').request(:post, '/definitions/bill/run', {facts:})
    head, body = received.pop

    expect(answer).to eq([200, {'total' => '2.3'}])
    expect(head).to start_with('POST /api/definitions/bill/run').
      and include('Authorization: Bearer secret', 'Content-Type: application/json', 'Accept: application/json')
    expect(body).to eq('{"facts":{"rate":0.1,"hours":1.1,"on":"2026-07-01","at":"2026-07-01T09:30:00Z"}}')
  end

  it 'reads an answer that is not JSON as an error naming the status' do
    port, = serve(502, '<html>Bad Gateway</html>')

    expect(described_class.new("http://127.0.0.1:#{port}", 'k').request(:get, '/definitions')).
      to eq([502, {'error' => 'the service answered HTTP 502 with something other than JSON'}])
  end

  it 'raises Unreachable when nothing answers' do
    port = closed_port

    expect { described_class.new("http://127.0.0.1:#{port}", 'k').request(:get, '/definitions') }.
      to raise_error(Reckoning::Client::Unreachable, %r{could not reach the service at http://127\.0\.0\.1:#{port}})
  end
end
