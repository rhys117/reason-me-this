require_relative 'lib/reason_me_this/version'

Gem::Specification.new do |spec|
  spec.name = 'reason_me_this'
  spec.version = ReasonMeThis::VERSION
  spec.authors = ['Rhys Murray']
  spec.license = 'MIT'
  spec.summary = 'Run, explain and publish Reason Me This blueprints from Ruby, and the rmt CLI'
  spec.description = 'The client for reason-me-this.com: runs, explains, pushes and publishes blueprints over HTTP, keeping numbers exact.'
  spec.required_ruby_version = '>= 3.4'
  spec.files = Dir['lib/**/*.{rb,tt}', 'exe/*', 'README.md', 'LICENSE.txt']
  spec.bindir = 'exe'
  spec.executables = ['rmt']
  spec.require_paths = ['lib']
  spec.homepage = 'https://reason-me-this.com'
  spec.metadata['documentation_uri'] = 'https://reason-me-this.com/docs/'
  spec.metadata['source_code_uri'] = 'https://github.com/rhys117/reason-me-this'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.add_dependency 'bigdecimal'
  spec.add_dependency 'json', '>= 2.10'
end
