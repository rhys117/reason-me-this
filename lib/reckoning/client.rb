require 'reckoning/client/version'
require 'reckoning/client/values'
require 'reckoning/client/answer'
require 'reckoning/client/errors'
require 'reckoning/client/explanation'

module Reckoning
  class Client
    def initialize(connection:)
      @connection = connection
    end

    def run(name, facts, calculation: nil, version: nil, trace: false)
      name, pinned = name.to_s.split('@', 2)
      version ||= pinned&.match?(/\A\d+\z/) ? Integer(pinned) : pinned
      answer = request(:post, "/definitions/#{name}/run", {facts:, calculation:, version:, trace: (true if trace)}.compact)
      trace ? Explanation.new(outputs: Answer.new(answer[:outputs]), steps: answer[:steps]) : Answer.new(answer)
    end

    def explain(name, facts, calculation: nil, version: nil) = run(name, facts, calculation:, version:, trace: true)

    def push(name, yaml:, cases: '') = request(:put, "/definitions/#{name}", {yaml:, cases:}, invalid: Rejected)

    def publish(name) = request(:post, "/definitions/#{name}/publish", invalid: Rejected)[:version]

    def definitions = request(:get, '/definitions')[:definitions]

    def definition(name) = request(:get, "/definitions/#{name}")

    private

    def request(method, path, body = nil, invalid: InvalidFacts)
      status, answer = @connection.request(method, path, body)
      answer = Values.read(answer)
      status.between?(200, 299) ? answer : raise(refusal(status, answer, invalid))
    end

    def refusal(status, answer, invalid)
      case [status, answer]
      in [401, _] then Unauthorized.new('the service refused the API key')
      in [404, {error:}] then NotFound.new(error)
      in [422, {problems:}] then invalid.new(answer)
      in [422, {error:}] then StepFailed.new(error)
      in [503, {error:}] then Timeout.new(error)
      else Error.new(["the service answered HTTP #{status}", answer[:error]].compact.join(': '))
      end
    end
  end
end
