require 'reckoning/client/version'
require 'reckoning/client/values'
require 'reckoning/client/answer'

module Reckoning
  class Client
    def initialize(connection:)
      @connection = connection
    end

    def run(name, facts, calculation: nil, version: nil)
      name, pinned = name.to_s.split('@', 2)
      version ||= pinned&.match?(/\A\d+\z/) ? Integer(pinned) : pinned
      _status, outputs = @connection.request(:post, "/definitions/#{name}/run", {facts:, calculation:, version:}.compact)
      Answer.new(outputs)
    end
  end
end
