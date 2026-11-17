# typed: strict

module ReasonMeThis
  class Blueprint
    # A step of a calculation, as its method hands it back, so that it can be given a condition.
    class Step
      #: (Symbol, Symbol, untyped) -> void
      def initialize(name, type, spec)
        @step = {name:, type => spec} #: Hash[Symbol, untyped]
      end

      # The step runs only when the condition is true. Skipped, its value is the else formula, or blank without one.
      #: (String, ?else: (String | Numeric | bool)?) -> Step
      def when(condition, else: nil)
        @step[:when] = condition
        otherwise = binding.local_variable_get(:else)
        @step[:else] = otherwise unless otherwise.nil?
        self
      end

      #: -> Hash[Symbol, untyped]
      def to_h = @step
    end
  end
end
