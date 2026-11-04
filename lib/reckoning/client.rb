require 'reckoning/client/version'
require 'reckoning/client/values'
require 'reckoning/client/answer'
require 'reckoning/client/errors'
require 'reckoning/client/explanation'
require 'reckoning/client/connection'
require 'reckoning/client/configuration'
require 'reckoning/client/model'
require 'forwardable'

module Reckoning
  class Client
    class << self
      extend Forwardable

      def_delegators :default, :run, :explain, :push, :publish, :definitions, :definition

      def configure
        yield configuration
        @default = nil
      end

      def configuration = @configuration ||= Configuration.new

      def default = @default ||= new(**configuration.to_h.compact)
    end

    def initialize(url: nil, api_key: nil, connection: Connection.new(url, api_key))
      @connection = connection
    end

    def run(name, facts, calculation: nil, version: nil, trace: false)
      name, pinned = name.to_s.split('@', 2)
      version ||= pinned&.match?(/\A\d+\z/) ? Integer(pinned) : pinned
      answer = request(:post, at(name, :run), {facts:, calculation:, version:, trace: (true if trace)}.compact)
      trace ? Explanation.new(outputs: Answer.new(answer[:outputs]), steps: answer[:steps]) : Answer.new(answer)
    end

    def explain(name, facts, calculation: nil, version: nil) = run(name, facts, calculation:, version:, trace: true)

    def push(name, yaml:, cases: '') = request(:put, at(name), {yaml:, cases:}, invalid: Rejected)

    def publish(name) = request(:post, at(name, :publish), invalid: Rejected)[:version]

    def definitions = request(:get, '/definitions')[:definitions]

    def definition(name) = request(:get, at(name))

    private

    def at(name, *action) = ['/definitions', name, *action].join('/')

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
