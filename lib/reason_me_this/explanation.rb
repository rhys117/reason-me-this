module ReasonMeThis
  Explanation = Data.define(:outputs, :steps) do
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

      found(Array(step[:steps]), rest, &missing)
    end
  end
end
