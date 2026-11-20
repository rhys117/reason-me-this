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
        @examples = [] #: Array[Hash[Symbol, untyped]]
      end

      #: Array[Hash[Symbol, untyped]]
      attr_reader :examples

      #: { () [self: Fields] -> void } -> void
      def inputs(&block)
        @inputs.instance_eval(&block)
      end

      #: (Symbol, String | Numeric | bool) -> Step
      def formula(name, expression) = step(name, :formula, expression)

      #: (Symbol, ?pick: Symbol, ?otherwise: (String | Numeric | bool)?) { () [self: Rules] -> void } -> Step
      def rules(name, pick: :first, otherwise: nil, &block)
        rules = Rules.new
        rules.instance_eval(&block)
        step(name, :rules, {pick:, otherwise:, rules: rules.to_a}.compact)
      end

      #: (Symbol, table: Symbol, ?where: Hash[Symbol, Symbol], ?value: Symbol?, ?on: Symbol?, ?band: Hash[Symbol, Symbol]?,
      #|  ?default: (String | Numeric | bool)?) -> Step
      def lookup(name, table:, where: {}, value: nil, on: nil, band: nil, default: nil)
        step(name, :lookup, {table:, where:, value:, on:, band:, default:}.compact)
      end

      #: (Symbol, table: Symbol, given: Hash[Symbol, Symbol], hit: Symbol, ?value: Symbol?, ?default: (String | Numeric | bool)?) -> Step
      def decide(name, table:, given:, hit:, value: nil, default: nil)
        step(name, :decide, {table:, given:, hit:, value:, default:}.compact)
      end

      #: (Symbol, Symbol, ?over: Symbol?, ?with: Hash[Symbol, String | Numeric | bool]?, ?position: Symbol?, ?carry: Hash[Symbol, Symbol]?,
      #|  ?start: Hash[Symbol, String | Numeric | bool]?, ?earlier: Symbol?, ?update: bool) -> Step
      def run(name, calculation, over: nil, with: nil, position: nil, carry: nil, start: nil, earlier: nil, update: false)
        step(name, :run, {calculation:, over:, with:, position:, carry:, start:, earlier:, update: update || nil}.compact)
      end

      #: (Symbol, Symbol, ?times: (String | Integer)?, ?until: Symbol?, ?limit: Integer?, ?with: Hash[Symbol, String | Numeric | bool]?,
      #|  ?position: Symbol?, ?carry: Hash[Symbol, Symbol]?, ?start: Hash[Symbol, String | Numeric | bool]?, ?earlier: Symbol?) -> Step
      def repeat(name, calculation, times: nil, until: nil, limit: nil, with: nil, position: nil, carry: nil, start: nil, earlier: nil)
        spec = {calculation:, times:, until: binding.local_variable_get(:until), limit:, with:, position:, carry:, start:, earlier:}
        step(name, :repeat, spec.compact)
      end

      #: (Symbol, Symbol, of: Symbol) -> Step
      def sum(name, output, of:) = step(name, :sum, {output:, of:})

      #: (Symbol, of: Symbol, by: Array[Symbol], ?sum: Array[Symbol]?) -> Step
      def group(name, of:, by:, sum: nil) = step(name, :group, {of:, by:, sum:}.compact)

      #: (Symbol, Array[Symbol], ?pick: Symbol) -> Step
      def compare(name, steps, pick: :highest) = step(name, :compare, {steps:, pick:})

      #: (Symbol, ?from: String?, ?to: String?, ?over: Symbol?, ?without: untyped, ?at_hours: (Array[Integer] | String)?, ?at_times: String?,
      #|  ?within: untyped, ?after: untyped) -> Step
      def slice(name, from: nil, to: nil, over: nil, without: nil, at_hours: nil, at_times: nil, within: nil, after: nil)
        step(name, :slice, {from:, to:, over:, without:, at_hours:, at_times:, within:, after:}.compact)
      end

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

      # A worked example: facts with the outputs they should give, any of them, and the events they should set off.
      #: (String, expect: Hash[Symbol, untyped], ?facts: Hash[Symbol, untyped], ?events: Array[Symbol]?) -> void
      def example(name, expect:, facts: {}, events: nil)
        @examples << {name:, facts:, expect:, events:}.compact
      end

      #: -> Hash[Symbol, untyped]
      def to_h
        {inputs: @inputs.to_h, steps: @steps.map(&:to_h), outputs: @outputs, events: @events}.reject { |key, held| key != :steps && held.empty? }
      end
    end
  end
end
