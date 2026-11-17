# typed: strict

module ReasonMeThis
  class Blueprint
    # The rules of a rules step, in the order they are tried.
    class Rules
      #: -> void
      def initialize
        @rules = [] #: Array[Hash[Symbol, untyped]]
      end

      # A rule without a value gives its name.
      #: (Symbol, String, ?value: (String | Numeric | bool)?) -> void
      def rule(name, condition, value: nil)
        @rules << {name:, when: condition, value:}.compact
      end

      #: -> Array[Hash[Symbol, untyped]]
      def to_a = @rules
    end
  end
end
