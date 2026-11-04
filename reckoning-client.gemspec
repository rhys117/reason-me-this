require_relative 'lib/reckoning/client/version'

Gem::Specification.new do |spec|
  spec.name = 'reckoning-client'
  spec.version = Reckoning::Client::VERSION
  spec.authors = ['Rhys Murray']
  spec.summary = 'Call a hosted Reckoning service from Ruby'
  spec.description = 'Runs, explains, pushes and publishes Reckoning definitions over HTTP, keeping numbers exact.'
  spec.required_ruby_version = '>= 3.4'
  spec.files = Dir['lib/**/*.rb', 'README.md']
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.add_dependency 'bigdecimal'
  spec.add_dependency 'json', '>= 2.10'
end
