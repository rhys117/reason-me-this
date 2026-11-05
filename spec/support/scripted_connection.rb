class ScriptedConnection
  attr_reader :requests

  def initialize(answers)
    @answers = answers
    @requests = []
  end

  def request(method, path, body = nil)
    @requests << [method, path, body]
    @answers.fetch([method, path]) { raise "no answer scripted for #{method} #{path}" }
  end
end
