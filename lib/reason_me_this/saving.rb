module ReasonMeThis
  Saving = Data.define(:on, :into, :from, :by, :columns) do
    def self.of(on: nil, into: nil, from: nil, by: nil, **columns) = new(on:, into:, from:, by:, columns:)

    def apply(record, explained)
      return rows(record.public_send(into), Array(explained.at(from))) if into

      target = on ? record.public_send(on) : record
      columns.each { |column, source| target.public_send(:"#{column}=", stored(target, column, value(source, explained))) }
      target.save! if on
    end

    private

    def value(source, explained) = source.respond_to?(:call) ? source.call(explained) : explained.at(source)

    def stored(target, column, value)
      json = target.respond_to?(:type_for_attribute) && target.type_for_attribute(column.to_s).type == :json
      json ? Values.text(value) : value
    end

    def rows(association, found)
      found.each do |row|
        child = association.find_or_initialize_by(by => row[by])
        child.assign_attributes(columns.empty? ? row.slice(*child.attribute_names.map(&:to_sym)) : columns.transform_values { |key| row[key.to_sym] })
        child.save!
      end
    end
  end
end
