require 'reckoning/client/version'
require 'reckoning/client/values'
require 'reckoning/client/answer'

module Reckoning
  class Client
    def initialize(connection:)
      @connection = connection
    end

    def run(name, facts, calculation: nil)
      _status, outputs = @connection.request(:post, "/definitions/#{name}/run", {facts:, calculation:}.compact)
      Answer.new(outputs)
    end
  end
end
