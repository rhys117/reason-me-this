require 'socket'

module ClosedPort
  def closed_port = TCPServer.new('127.0.0.1', 0).then { |server| server.addr[1].tap { server.close } }
end
