require 'reckoning/client/version'
require 'reckoning/client/values'
require 'reckoning/client/answer'
require 'reckoning/client/errors'

module Reckoning
  class Client
    def initialize(connection:)
      @connection = connection
    end

    def run(name, facts, calculation: nil, version: nil)
      name, pinned = name.to_s.split('@', 2)
      version ||= pinned&.match?(/\A\d+\z/) ? Integer(pinned) : pinned
      Answer.new(request(:post, "/definitions/#{name}/run", {facts:, calculation:, version:}.compact))
    end

    private

    def request(method, path, body = nil)
      status, answer = @connection.request(method, path, body)
      answer = Values.read(answer)
      status.between?(200, 299) ? answer : raise(refusal(status, answer))
    end

    def refusal(status, answer)
      case [status, answer]
      in [401, _] then Unauthorized.new('the service refused the API key')
      in [404, {error:}] then NotFound.new(error)
      in [422, {problems:}] then InvalidFacts.new(problems)
      in [422, {error:}] then StepFailed.new(error)
      in [503, {error:}] then Timeout.new(error)
      else Error.new(["the service answered HTTP #{status}", answer[:error]].compact.join(': '))
      end
    end
  end
end
