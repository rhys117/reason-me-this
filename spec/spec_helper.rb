require 'reason_me_this'
require_relative 'support/closed_port'
require_relative 'support/fake_connection'
require_relative 'support/scripted_connection'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
  config.order = :random
  config.include ClosedPort
end
