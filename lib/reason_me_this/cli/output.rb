module ReasonMeThis
  class CLI
    module Output
      def self.for(out, format)
        terminal = out.respond_to?(:tty?) && out.tty?
        return Json.new(out) if (format || (terminal ? :text : :json)) == :json

        Text.new(out, colour: terminal && !ENV.key?('NO_COLOR'))
      end

      class Json
        def initialize(out)
          @out = out
        end

        def show(_kind, payload, **)
          @out.puts(JSON.pretty_generate(payload))
        end
      end

      class Text
        def initialize(out, colour:)
          @out = out
          @colour = colour
        end

        def show(kind, payload, **context)
          @out.puts(send(kind, symbolized(payload), **context))
        end

        private

        def symbolized(value)
          case value
          when Hash then value.to_h { |key, item| [key.to_sym, symbolized(item)] }
          when Array then value.map { |item| symbolized(item) }
          else value
          end
        end

        def outputs(values) = fields(values, 0).join("\n")

        def trace(explained)
          [outputs(explained[:outputs]), '', bold('How it was worked out'), *steps(explained[:steps], 1), *events(Array(explained[:events]))].join("\n")
        end

        def events(list)
          return [] if list.empty?

          width = list.map { |event| event[:name].to_s.size }.max
          ['', bold('Sets off'), *list.map { |event| "  #{event[:name].to_s.ljust(width)}  #{carried(event[:data])}".rstrip }]
        end

        def carried(data) = data.map { |name, value| "#{name} #{value}" }.join(', ')

        def problems(answer)
          listed = answer[:problems]
          return pass('No problems') if listed.empty?

          [fail("#{listed.size} #{listed.size == 1 ? 'problem' : 'problems'}"), *listed.map { |problem| "  • #{problem}" }].join("\n")
        end

        def error(answer) = fail(answer[:error])

        def refusal(answer) = answer.key?(:problems) ? problems(answer) : error(answer)

        def report(answer)
          answer.key?(:error) || answer[:problems]&.any? ? refusal(answer) : cases(answer)
        end

        def cases(answer)
          passed, failed = answer.values_at(:passed, :failed).map(&:to_i)
          failing = answer[:cases].reject { |result| result[:passed] }
          return pass("#{passed} #{passed == 1 ? 'case' : 'cases'} passed") if failing.empty?

          [fail("#{failed} of #{passed + failed} cases failed"), *failing.flat_map { |result| failed_case(result) }].join("\n")
        end

        def failed_case(result)
          detail = if result[:error]
                     ["      #{result[:error]}"]
                   else
                     result[:differences].map { |d| "      #{d[:output]}: expected #{d[:expected]}, got #{d[:actual]}" }
                   end
          ['', "  #{fail(result[:name])}", *detail]
        end

        def published(answer, name:)
          waiting = answer.key?(:live_version) && answer[:live_version] != answer[:version]
          live = answer[:live_version] ? "v#{answer[:live_version]} is live" : 'none is live'
          pass("Published #{name} v#{answer[:version]}#{", in effect from #{answer[:effective_from]}; #{live}" if waiting}")
        end

        def definitions(answer)
          rows = answer[:definitions].map do |definition|
            [definition[:name], definition[:published_version] ? "v#{definition[:published_version]}" : 'draft only', definition[:updated_at].to_s[0, 10]]
          end
          table([%w[NAME PUBLISHED UPDATED], *rows]).join("\n")
        end

        def created(answer) = answer[:created].map { |path| "Wrote #{path}" }.join("\n")

        def describe(answer)
          types = answer[:steps].map { |name, type| "  #{name.to_s.ljust(10)} #{type[:purpose]}" }
          functions = answer[:formulas][:usage].map { |_name, usage| "  #{usage}" }
          [bold('Step types'), *types, '', bold('Formula functions'), *functions, '',
           'Run rmt describe --json for an example of each, with what it gives, or rmt guide for the whole guide.'].join("\n")
        end

        def fields(values, depth)
          width = values.keys.map { |name| name.to_s.size }.max
          values.flat_map do |name, value|
            label = "#{'  ' * depth}#{name}"
            case value
            when Hash then [label, *fields(value, depth + 1)]
            when Array then list(label, value, width, depth)
            else "#{label.ljust(width + (2 * depth))}  #{value}"
            end
          end
        end

        def list(label, value, width, depth)
          return ["#{label.ljust(width + (2 * depth))}  #{value.join(', ')}"] unless rows?(value)

          [label, *table(columns(value)).map { |line| "#{'  ' * (depth + 1)}#{line}" }]
        end

        def rows?(list) = list.any? && list.all?(Hash)

        def columns(rows)
          names = rows.flat_map(&:keys).uniq
          [names.map(&:to_s), *rows.map { |row| names.map { |name| cell(row[name]) } }]
        end

        def cell(value) = value.is_a?(Array) || value.is_a?(Hash) ? value.size.to_s : value.to_s

        def table(lines)
          widths = lines.transpose.map { |column| column.map { |cell| cell.to_s.size }.max }
          lines.map { |line| line.each_with_index.map { |cell, index| cell.to_s.ljust(widths[index]) }.join('  ').rstrip }
        end

        def steps(list, depth)
          lines = list.map { |step| ["#{'  ' * depth}#{step[:step]}", summary(step[:value], step[:of]), detail(step)] }
          names = lines.map { |name, *| name.size }.max
          values = lines.select(&:last).map { |_, value, _| value.size }.max
          list.zip(lines).flat_map { |step, line| [step_line(*line, names, values), *step_rows(step, depth)] }
        end

        def step_line(name, value, detail, names, values)
          detail ? "#{name.ljust(names)}  #{value.ljust(values)}  #{detail}" : "#{name.ljust(names)}  #{value}"
        end

        def step_rows(step, depth)
          Array(step[:rows]).each_with_index.flat_map { |row, index| ["#{'  ' * (depth + 1)}row #{index + 1}", *steps(row, depth + 2)] }
        end

        def summary(value, over)
          return "#{value.size} #{value.size == 1 ? 'row' : 'rows'}#{" over #{over}" if over}" if value.is_a?(Array)

          value.is_a?(Hash) ? value.map { |name, item| "#{name} #{item}" }.join(', ') : value.to_s
        end

        def detail(step)
          return dim(step[:formula]) if step[:formula]
          return dim("row #{step[:row].map { |name, value| "#{name} #{value}" }.join(', ')}") if step[:row]

          dim("from #{step[:of]}") if step[:of] && !step[:value].is_a?(Array)
        end

        def pass(message) = paint("✓ #{message}", 32)

        def fail(message) = paint("✗ #{message}", 31)

        def bold(text) = paint(text, 1)

        def dim(text) = paint(text, 2)

        def paint(text, code) = @colour ? "\e[#{code}m#{text}\e[0m" : text
      end
    end
  end
end
