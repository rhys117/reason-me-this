Reckoning::Client.configure do |config|
  config.url = ENV.fetch('RECKONING_API_URL', nil)
  config.api_key = ENV.fetch('RECKONING_API_KEY', nil)
end
