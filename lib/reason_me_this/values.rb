require 'bigdecimal'
require 'date'
require 'json'
require 'time'

module ReasonMeThis
  module Values
    NUMBER = /\A-?\d+(\.\d+)?\z/
    DATE = /\A\d{4}-\d{2}-\d{2}\z/
    TIME = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})\z/

    module_function

    def read(value)
      deep(value) do |leaf|
        case leaf
        when NUMBER then BigDecimal(leaf)
        when DATE then date(leaf)
        when TIME then time(leaf)
        else leaf
        end
      end
    end

    # A decimal goes out as a JSON number written in full, so the service reads the value that was typed.
    def write(value)
      deep(value) do |leaf|
        case leaf
        when BigDecimal then JSON::Fragment.new(leaf.to_s('F'))
        when Date, Time then leaf.iso8601
        else leaf
        end
      end
    end

    def text(value)
      deep(value) do |leaf|
        case leaf
        when BigDecimal then leaf.frac.zero? ? leaf.to_i.to_s : leaf.to_s('F')
        when Date, Time then leaf.iso8601
        else leaf
        end
      end
    end

    def date(text)
      Date.iso8601(text)
    rescue Date::Error
      text
    end

    def time(text)
      Time.iso8601(text)
    rescue ArgumentError
      text
    end

    def deep(value, &)
      case value
      when Hash then value.to_h { |key, item| [key.is_a?(String) ? key.to_sym : key, deep(item, &)] }
      when Array then value.map { |item| deep(item, &) }
      else yield value
      end
    end
  end
end
