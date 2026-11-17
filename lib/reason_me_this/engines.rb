module ReasonMeThis
  # The engines that run blueprints in this process, with no service. They are licensed separately: an engine's
  # own package provides reason_me_this/engines/NAME, which registers how to build its connection.
  module Engines
    NAME = /\A[a-z0-9_]+\z/
    @builders = {}

    def self.register(name, &builder) = @builders[name.to_sym] = builder

    def self.connection(name, blueprints: nil)
      raise Error.new("an engine is named in lowercase letters, digits and underscores, not #{name}") unless NAME.match?(name.to_s)

      @builders.fetch(name.to_sym) { load(name) }.call(blueprints:)
    end

    def self.load(name)
      require "reason_me_this/engines/#{name}"
      @builders.fetch(name.to_sym)
    rescue LoadError => e
      raise EngineMissing.new("the #{name} engine could not be loaded: #{e.message}. It is licensed separately; add the gems you were " \
        'given to your Gemfile, or configure a url to use the service')
    end
    private_class_method :load
  end
end
