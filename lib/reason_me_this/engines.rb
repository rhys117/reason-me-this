module ReasonMeThis
  # The engines that run blueprints in this process, with no service. They are licensed separately: an engine's
  # own package provides reason_me_this/engines/NAME, which registers how to build its connection.
  module Engines
    NAME = /\A[a-z0-9_]+\z/
    @builders = {}

    def self.register(name, &builder) = @builders[name.to_sym] = builder

    # A setting is handed to the engine only when it was given and the engine takes it, so an engine with no native
    # loop is built as it always was.
    def self.connection(name, blueprints: nil, **settings)
      raise Error.new("an engine is named in lowercase letters, digits and underscores, not #{name}") unless NAME.match?(name.to_s)

      builder = @builders.fetch(name.to_sym) { load(name) }
      taken = builder.parameters.filter_map { |kind, setting| setting if %i[key keyreq].include?(kind) }
      builder.call(blueprints:, **settings.compact.slice(*taken))
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
