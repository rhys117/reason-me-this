require 'bigdecimal'
require 'date'

module Reckoning
  class Client
    module Values
      NUMBER = /\A-?\d+(\.\d+)?\z/
      DATE = /\A\d{4}-\d{2}-\d{2}\z/

      module_function

      def read(value)
        case value
        when Hash then value.to_h { |key, item| [key.to_sym, read(item)] }
        when Array then value.map { |item| read(item) }
        when NUMBER then BigDecimal(value)
        when DATE then Date.iso8601(value)
        else value
        end
      end
    end
  end
end
