module ReasonMeThis
  Event = Data.define(:name, :data) do
    def self.read(event) = new(name: event[:name].to_sym, data: event.fetch(:data, {}))
  end

  Explanation = Data.define(:outputs, :steps, :version, :events) do
    def initialize(outputs:, steps:, version: nil, events: []) = super

    def at(path)
      names = path.to_s.split('.')
      return outputs[names.first] if names.one? && outputs.to_h.key?(names.first.to_sym)

      found(steps, names) { raise Error.new("no step #{path} in the trace") }
    end

    private

    def found(list, names, &missing)
      step = list.find { |each| each[:step].to_s == names.first } or return missing.call
      rest = names.drop(1)
      return step[:value] if rest.empty?
      return step[:rows].map { |row| found(row, rest, &missing) } if step[:rows]
      return found(step[:steps], rest, &missing) if step[:steps]

      within(step[:value], rest, &missing)
    end

    def within(value, names, &missing)
      return value if names.empty?
      return value.map { |row| within(row, names, &missing) } if value.is_a?(Array)
      return missing.call unless value.is_a?(Hash) && value.key?(names.first.to_sym)

      within(value[names.first.to_sym], names.drop(1), &missing)
    end
  end
end
