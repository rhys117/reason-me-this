# The specs tagged :engine run the licensed engine, which this gem does not depend on. Run them with a gemfile
# that adds it.
ENGINE_BUNDLED =
  begin
    ReasonMeThis::Engines.connection(:rust)
    true
  rescue ReasonMeThis::EngineMissing
    false
  end

RSpec.configure do |config|
  config.before(:each, :engine) do
    skip 'the licensed engine is not in this bundle; run with a gemfile that adds it' unless ENGINE_BUNDLED
  end
end
