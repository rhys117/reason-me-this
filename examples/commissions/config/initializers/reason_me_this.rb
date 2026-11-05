ReasonMeThis.configure do |config|
  config.url = ENV.fetch('RMT_API_URL', nil)
  config.api_key = ENV.fetch('RMT_API_KEY', nil)
end
