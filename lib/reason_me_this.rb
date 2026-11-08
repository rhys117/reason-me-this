require 'reason_me_this/version'
require 'reason_me_this/values'
require 'reason_me_this/answer'
require 'reason_me_this/errors'
require 'reason_me_this/explanation'
require 'reason_me_this/webhook'
require 'reason_me_this/connection'
require 'reason_me_this/configuration'
require 'reason_me_this/saving'
require 'reason_me_this/recipe'
require 'reason_me_this/model'
require 'forwardable'

module ReasonMeThis
  class << self
    extend Forwardable

    def_delegators :default, :run, :explain, :push, :publish, :definitions, :definition

    def configure
      yield configuration
      @default = nil
    end

    def configuration = @configuration ||= Configuration.new

    def default = @default ||= Client.new(**configuration.to_h.compact)
  end

  class Client
    def initialize(url: nil, api_key: nil, connection: Connection.new(url, api_key))
      @connection = connection
    end

    def run(name, facts, calculation: nil, version: nil, on: nil, trace: false) # rubocop:disable Metrics/ParameterLists
      name, pinned = name.to_s.split('@', 2)
      version ||= pinned&.match?(/\A\d+\z/) ? Integer(pinned) : pinned
      answer = request(:post, at(name, :run), {facts:, calculation:, version:, on:, trace: (true if trace)}.compact)
      return Answer.new(answer) unless trace

      Explanation.new(outputs: Answer.new(answer[:outputs]), steps: answer[:steps], version: answer[:version],
                      events: Array(answer[:events]).map { |event| Event.read(event) })
    end

    def explain(name, facts, calculation: nil, version: nil, on: nil) = run(name, facts, calculation:, version:, on:, trace: true)

    def push(name, yaml:, cases: '') = request(:put, at(name), {yaml:, cases:}, invalid: Rejected)

    # live: false leaves the version that is live now live, so the new one waits.
    def publish(name, effective_from: nil, live: nil)
      body = {effective_from:, live:}.compact
      request(:post, at(name, :publish), (body unless body.empty?), invalid: Rejected)
    end

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
      in [410, {error:}] then Gone.new(error)
      in [422, {problems:}] then invalid.new(answer)
      in [422, {error:}] then StepFailed.new(error)
      in [503, {error:}] then Timeout.new(error)
      else Error.new(["the service answered HTTP #{status}", answer[:error]].compact.join(': '))
      end
    end
  end
end
