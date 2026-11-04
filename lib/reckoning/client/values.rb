require 'bigdecimal'
require 'date'
require 'json'
require 'time'

module Reckoning
  class Client
    module Values
      NUMBER = /\A-?\d+(\.\d+)?\z/
      DATE = /\A\d{4}-\d{2}-\d{2}\z/

      module_function

      def read(value)
        deep(value) do |leaf|
          case leaf
          when NUMBER then BigDecimal(leaf)
          when DATE then Date.iso8601(leaf)
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

      def deep(value, &)
        case value
        when Hash then value.to_h { |key, item| [key.is_a?(String) ? key.to_sym : key, deep(item, &)] }
        when Array then value.map { |item| deep(item, &) }
        else yield value
        end
      end
    end
  end
end
