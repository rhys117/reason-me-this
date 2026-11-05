module ReasonMeThis
  Recipe = Data.define(:blueprint, :calculation, :facts, :savings, :hooks) do
    def self.build(with:, calculation:, &steps)
      builder = Recipe::Builder.new
      builder.instance_eval(&steps) if steps
      new(blueprint: with, calculation:, facts: builder.facts || proc { {} }, savings: builder.savings, hooks: builder.hooks)
    end
  end

  class Recipe
    class Builder
      attr_reader :savings, :hooks

      def initialize
        @savings = []
        @hooks = []
      end

      def facts(&given)
        @facts = given if given
        @facts
      end

      def saves(**) = savings << Saving.of(**)

      def after(&hook) = hooks << hook
    end
  end
end
