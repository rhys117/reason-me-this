# typed: strict

require 'time'
require 'reason_me_this/blueprint/fields'
require 'reason_me_this/blueprint/rules'
require 'reason_me_this/blueprint/step'
require 'reason_me_this/blueprint/calculation'

module ReasonMeThis
  # A blueprint written in Ruby. It builds the document a blueprint file holds, so it is pushed, checked and run
  # as one is.
  class Blueprint
    #: { () [self: Blueprint] -> void } -> Blueprint
    def self.define(&block)
      blueprint = new
      blueprint.instance_eval(&block)
      blueprint
    end

    # The document with text for every name, and a time as the ISO 8601 text a blueprint file holds one as.
    #: (untyped) -> untyped
    def self.plain(value)
      case value
      when Hash then value.to_h { |key, held| [key.to_s, plain(held)] }
      when Array then value.map { |held| plain(held) }
      when Symbol then value.to_s
      when Time then value.iso8601
      else value
      end
    end

    #: -> void
    def initialize
      @imports = [] #: Array[String]
      @tables = {} #: Hash[Symbol, Array[Hash[Symbol, untyped]]]
      @calculations = {} #: Hash[Symbol, Calculation]
    end

    # A path to a blueprint file, or the name of a blueprint the service or the engine knows.
    #: (*String) -> void
    def import(*names)
      @imports.concat(names)
    end

    #: (Symbol, Array[Hash[Symbol, untyped]]) -> void
    def table(name, rows)
      @tables[name] = rows
    end

    # The first calculation is the one run when none is named.
    #: (Symbol) { () [self: Calculation] -> void } -> void
    def calculation(name, &block)
      calculation = Calculation.new
      calculation.instance_eval(&block)
      @calculations[name] = calculation
    end

    #: -> Hash[String, untyped]
    def to_h
      document = {imports: @imports, tables: @tables}.reject { |_key, held| held.empty? }
      Blueprint.plain({**document, calculations: @calculations.transform_values(&:to_h)})
    end

    #: -> String
    def yaml
      require 'reason_me_this/blueprint/yaml'
      Yaml.write(to_h)
    end
  end
end
