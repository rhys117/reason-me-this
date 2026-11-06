module ReasonMeThis
  Recipe = Data.define(:blueprint, :calculation, :facts, :savings, :hooks, :handlers, :receipts) do
    def self.build(with:, calculation:, &steps)
      builder = Recipe::Builder.new
      builder.instance_eval(&steps) if steps
      new(blueprint: with, calculation:, facts: builder.facts || proc { {} }, savings: builder.savings, hooks: builder.hooks, handlers: builder.handlers,
          receipts: builder.receipts)
    end
  end

  class Recipe
    class Builder
      attr_reader :savings, :hooks, :handlers, :receipts

      def initialize
        @savings = []
        @hooks = []
        @handlers = Hash.new { |all, name| all[name] = [] }
      end

      def facts(&given)
        @facts = given if given
        @facts
      end

      def saves(**) = savings << Saving.of(**)

      def after(&hook) = hooks << hook

      def on(event, &handler) = handlers[event.to_sym] << handler

      def keeps_receipts = @receipts = true
    end
  end
end
