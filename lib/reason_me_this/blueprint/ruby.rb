require 'bigdecimal'
require 'date'
require 'time'

module ReasonMeThis
  class Blueprint
    # Writes a blueprint's document as the Ruby that builds it, so that a blueprint kept as YAML can be kept as Ruby.
    # What a method of the blueprint cannot say is written with step or input, which take anything.
    class Ruby
      class Unwritable < Error
      end

      WORD = /\A[a-z_][a-z0-9_]*\z/i
      NAME = -> (held) { held.is_a?(String) }
      NAMES = -> (held) { held.is_a?(Hash) && held.values.all?(String) }
      NAME_LIST = -> (held) { held.is_a?(Array) && held.all?(String) }
      FORMULA = -> (held) { held.is_a?(String) || held.is_a?(Numeric) || [true, false].include?(held) }
      CONDITION = -> (held) { held.is_a?(String) || [true, false].include?(held) }
      FORMULAS = -> (held) { held.is_a?(Hash) && held.values.all?(&FORMULA) }
      TEXT = -> (held) { held.is_a?(String) }
      ANYTHING = -> (held) { !held.nil? }
      SYMBOLS = [NAME, NAMES, NAME_LIST].freeze

      LITERALS = {BigDecimal => -> (held) { "BigDecimal('#{held.to_s('F')}')" },
                  Time => -> (held) { "Time.iso8601('#{held.iso8601}')" },
                  Date => -> (held) { "Date.new(#{held.year}, #{held.month}, #{held.day})" }}.freeze

      def self.fits?(shape, spec)
        shape && spec.is_a?(Hash) && ([*shape[:first], *shape[:needs]] - spec.keys).empty? &&
          spec.all? { |key, held| shape[:keys].key?(key) && shape[:keys][key].call(held) }
      end

      RULE = {needs: [:name, :when], keys: {name: NAME, when: CONDITION, value: FORMULA}}.freeze
      RULES = {needs: [:pick, :rules],
               keys: {pick: NAME, otherwise: FORMULA,
                      rules: -> (held) {
                        held.is_a?(Array) && held.any? && held.all? do |rule|
                          rule.is_a?(Hash) && fits?(RULE, rule.transform_keys(&:to_sym))
                        end
                      }}}.freeze

      ROWS = {with: FORMULAS, position: NAME, carry: NAMES, start: FORMULAS, earlier: NAME}.freeze

      # What each step's method takes: the keys it puts first without their names, the keys it always writes, and
      # every key with what its value must be to be written that way.
      STEPS = {
        formula: {first: [:formula], keys: {formula: FORMULA}},
        lookup: {needs: [:table, :where], keys: {table: NAME, where: NAMES, value: NAME, on: NAME, band: NAMES, default: FORMULA}},
        decide: {needs: [:table, :given, :hit], keys: {table: NAME, given: NAMES, hit: NAME, value: NAME, default: FORMULA}},
        run: {first: [:calculation], keys: {calculation: NAME, over: NAME, **ROWS, update: -> (held) { held == true }}},
        repeat: {first: [:calculation],
                 keys: {calculation: NAME, times: -> (held) { held.is_a?(String) || held.is_a?(Integer) }, until: NAME, limit: Integer.method(:===), **ROWS}},
        sum: {first: [:output], needs: [:of], keys: {output: NAME, of: NAME}},
        group: {needs: [:of, :by], keys: {of: NAME, by: NAME_LIST, sum: NAME_LIST}},
        compare: {first: [:steps], needs: [:pick], keys: {steps: NAME_LIST, pick: NAME}},
        slice: {keys: {from: TEXT, to: TEXT, over: NAME, without: ANYTHING, at_hours: -> (held) { held.is_a?(String) || NAME_LIST.call(held.map(&:to_s)) },
                       at_times: TEXT, within: ANYTHING, after: ANYTHING}}
      }.freeze

      TYPES = {number: [:default, :optional, :one_of], string: [:default, :optional, :one_of], date: [:default, :optional],
               time: [:default, :optional], boolean: [:default, :optional], list: [:default, :optional, :of]}.freeze

      def self.write(document, name) = new(document).write(name)

      def initialize(document)
        @document = document
      end

      def write(name)
        unknown(@document, %w[imports tables calculations], 'a blueprint')
        parts = [imports, *tables, *@document.fetch('calculations', {}).map { |named, calculation| calculation(named, calculation) }].compact
        constant = name.to_s.upcase.gsub(/[^A-Z0-9]+/, '_').sub(/\A(?=\d|\z)/, 'BLUEPRINT_')
        "# typed: strict\n\n#{constant} = ReasonMeThis::Blueprint.define do\n#{indent(parts.join("\n\n"))}\nend #: ReasonMeThis::Blueprint\n"
      end

      private

      def imports
        names = @document['imports'] || []
        "import #{names.map { |name| literal(name) }.join(', ')}" if names.any?
      end

      def tables
        @document.fetch('tables', {}).map do |name, rows|
          "table #{symbol(name)}, [\n#{indent(rows.map { |row| "#{literal(row)}," }.join("\n"))}\n]"
        end
      end

      def calculation(name, calculation)
        unknown(calculation, %w[inputs steps outputs events], "calculation #{name}")
        inputs = calculation['inputs'] || {}
        parts = [
          ("inputs do\n#{indent(fields(inputs))}\nend" if inputs.any?),
          calculation.fetch('steps', []).map { |step| step(step) }.join("\n"),
          [*outputs(calculation['outputs'] || []), *calculation.fetch('events', []).map { |event| event(event) }].join("\n")
        ]
        "calculation #{symbol(name)} do\n#{indent(parts.compact.reject(&:empty?).join("\n\n"))}\nend"
      end

      def fields(fields) = fields.map { |name, field| field(name, field) }.join("\n")

      def field(name, field)
        type = field['type'].to_s.to_sym
        keys = field.except('type').transform_keys(&:to_sym)
        return "input #{arguments([symbol(name), symbol(type)], keys.transform_values { |held| literal(held) })}" unless typed?(type, keys)

        rows = keys.delete(:of)
        call = "#{type} #{arguments([symbol(name)], keys.to_h { |key, held| [key, key == :one_of ? words(held) : literal(held)] })}"
        rows ? "#{call} do\n#{indent(fields(rows))}\nend" : call
      end

      def typed?(type, keys)
        TYPES.key?(type) && (keys.keys - TYPES[type]).empty? && keys[:optional] != false && (!keys.key?(:default) || !keys[:default].nil?) &&
          (!keys.key?(:of) || rows?(keys[:of]))
      end

      def rows?(fields) = fields.is_a?(Hash) && fields.any? && fields.values.all?(Hash)

      def words(one_of) = NAMES.call(one_of) ? symbols(one_of) : literal(one_of)

      def step(step)
        name = step['name']
        types = step.keys - %w[name when else]
        raise Unwritable.new("step #{name} has #{types.join(', ')}; a step has one step type") unless types.size == 1
        raise Unwritable.new("step #{name} has else but no when") if step.key?('else') && !step.key?('when')

        method, taken, block = call(name, types.first.to_sym, step[types.first])
        return ["#{method} #{taken}", block].compact.join(' ') unless step.key?('when')

        "#{method}(#{taken})#{" #{block}" if block}.when(#{arguments([literal(step['when'])], step.slice('else').transform_values { |held| literal(held) })})"
      end

      def call(name, type, spec)
        spec = type == :formula ? {formula: spec} : keyed(spec)
        return rules(name, spec) if type == :rules && Ruby.fits?(RULES, spec)
        return written_by_type(name, type, spec) if Ruby.fits?(STEPS[type], spec)

        [:step, [symbol(name), symbol(type), literal(type == :formula ? spec[:formula] : spec)].join(', '), nil]
      end

      def keyed(spec) = spec.is_a?(Hash) ? spec.transform_keys(&:to_sym) : spec

      def written_by_type(name, type, spec)
        shape = STEPS[type]
        first = shape.fetch(:first, [])
        [type, arguments([symbol(name), *first.map { |key| written(shape, key, spec[key]) }],
                         spec.except(*first).to_h { |key, held| [key, written(shape, key, held)] }), nil]
      end

      def written(shape, key, held) = SYMBOLS.include?(shape[:keys][key]) ? symbols(held) : literal(held)

      def rules(name, spec)
        keys = {pick: symbol(spec[:pick]), **spec.slice(:otherwise).transform_values { |held| literal(held) }}
        rules = spec[:rules].map do |rule|
          "rule #{arguments([symbol(rule['name']), literal(rule['when'])], rule.slice('value').transform_values { |held| literal(held) })}"
        end
        [:rules, arguments([symbol(name)], keys), "do\n#{indent(rules.join("\n"))}\nend"]
      end

      def outputs(outputs)
        outputs.chunk_while { |earlier, later| earlier.is_a?(String) && later.is_a?(String) }.flat_map do |run|
          run.first.is_a?(String) ? ["outputs #{run.map { |name| symbol(name) }.join(', ')}"] : run.map { |output| output(output) }
        end
      end

      def output(output)
        unknown(output, %w[name type optional], "output #{output.is_a?(Hash) ? output['name'] : output.inspect}")
        "output #{arguments([symbol(output['name'])], {type: output['type'] && symbol(output['type']), optional: output['optional']}.compact)}"
      end

      def event(event)
        unknown(event, %w[name when data], "event #{event['name']}")
        raise Unwritable.new("event #{event['name']} needs when, the condition that sets it off") unless event['when'].is_a?(String)

        "event #{arguments([symbol(event['name']), literal(event['when'])], event.slice('data').transform_values { |names| symbols(names) })}"
      end

      def unknown(held, keys, named)
        raise Unwritable.new("#{named} should be a mapping") unless held.is_a?(Hash)

        extra = held.keys - keys
        raise Unwritable.new("#{named} has #{extra.join(', ')}, which cannot be written in Ruby; it takes #{keys.join(', ')}") if extra.any?
      end

      def arguments(first, keys) = [*first, *keys.map { |key, held| "#{key}: #{held}" }].join(', ')

      def symbols(held)
        case held
        when Hash then "{#{held.map { |key, name| "#{key(key)} #{symbol(name)}" }.join(', ')}}"
        when Array then "[#{held.map { |name| symbol(name) }.join(', ')}]"
        else symbol(held)
        end
      end

      def symbol(name) = WORD.match?(name.to_s) ? ":#{name}" : ":#{name.to_s.inspect}"

      def key(name) = WORD.match?(name.to_s) ? "#{name}:" : "#{name.to_s.inspect}:"

      def literal(held)
        case held
        when Hash then "{#{held.map { |key, inner| "#{key(key)} #{literal(inner)}" }.join(', ')}}"
        when Array then "[#{held.map { |inner| literal(inner) }.join(', ')}]"
        else scalar(held)
        end
      end

      def scalar(held)
        return held.match?(/['\\\n]|[^[:print:]]/) ? held.inspect : "'#{held}'" if held.is_a?(String)

        written = LITERALS.find { |kind, _written| held.is_a?(kind) }
        written ? written.last.call(held) : held.inspect
      end

      def indent(text) = text.gsub(/^(?=.)/, '  ')
    end
  end
end
