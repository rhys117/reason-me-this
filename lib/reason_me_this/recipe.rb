module ReasonMeThis
  class Recipe
    attr_reader :with, :calculation, :facts, :savings, :hooks

    def initialize(with:, calculation:, &steps)
      @with = with
      @calculation = calculation
      @facts = proc { {} }
      @savings = []
      @hooks = []
      Builder.new(self).instance_eval(&steps) if steps
    end

    class Builder
      def initialize(recipe)
        @recipe = recipe
      end

      def facts(&facts) = @recipe.instance_variable_set(:@facts, facts)

      def saves(**) = @recipe.savings << Saving.of(**)

      def after(&hook) = @recipe.hooks << hook
    end
  end
end
