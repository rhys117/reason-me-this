# typed: strict

module ReasonMeThis
  class Blueprint
    # A calculation: its inputs, its steps in the order they run, and what it hands back.
    class Calculation
      #: -> void
      def initialize
        @inputs = Fields.new #: Fields
        @steps = [] #: Array[Step]
        @outputs = [] #: Array[Symbol | Hash[Symbol, untyped]]
        @events = [] #: Array[Hash[Symbol, untyped]]
      end

      #: { () [self: Fields] -> void } -> void
      def inputs(&block)
        @inputs.instance_eval(&block)
      end

      #: (Symbol, String | Numeric | bool) -> Step
      def formula(name, expression) = step(name, :formula, expression)

      # A step of a type this gem has no method for, such as one a licensed engine adds.
      #: (Symbol, Symbol, untyped) -> Step
      def step(name, type, spec)
        step = Step.new(name, type, spec)
        @steps << step
        step
      end

      #: (*Symbol) -> void
      def outputs(*names)
        @outputs.concat(names)
      end

      # An output held to a type: a run fails when the value is of another, or blank without optional.
      #: (Symbol, ?type: Symbol?, ?optional: bool) -> void
      def output(name, type: nil, optional: false)
        @outputs << {name:, type:, optional: optional || nil}.compact
      end

      # An event set off when the condition is true, carrying the outputs unless data names what it carries.
      #: (Symbol, String, ?data: Array[Symbol]?) -> void
      def event(name, condition, data: nil)
        @events << {name:, when: condition, data:}.compact
      end

      #: -> Hash[Symbol, untyped]
      def to_h
        {inputs: @inputs.to_h, steps: @steps.map(&:to_h), outputs: @outputs, events: @events}.reject { |_key, held| held.empty? }
      end
    end
  end
end
