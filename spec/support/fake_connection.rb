class FakeConnection
  attr_reader :requests

  def initialize(status = 200, body = {})
    @status = status
    @body = body
    @requests = []
  end

  def request(method, path, body = nil)
    @requests << [method, path, body]
    [@status, @body]
  end
end
