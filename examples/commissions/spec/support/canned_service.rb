module CannedService
  class Connection
    attr_reader :requests

    def initialize(answer)
      @answer = answer
      @requests = []
    end

    def request(method, path, body = nil)
      @requests << [method, path, body]
      [200, @answer]
    end
  end

  def self.included(group)
    group.let(:service) { Connection.new(JSON.parse(Rails.root.join('spec/fixtures/full_year_statement.json').read)) }
    group.before { ReasonMeThis.configure { |config| config.connection = service } }
    group.after { ReasonMeThis.configure { |config| config.connection = nil } }
  end
end
