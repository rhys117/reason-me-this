# typed: false

require 'bigdecimal'
require 'yaml'

module ReasonMeThis
  class Blueprint
    # Writes a blueprint's document as the YAML a blueprint file holds: a decimal as the exact number it is, and a
    # value used twice in full both times, since a blueprint may not have an alias.
    class Yaml < Psych::Visitors::YAMLTree
      def self.write(document)
        tree = create
        tree << document
        tree.tree.yaml.delete_prefix("---\n")
      end

      def register(_target, node) = node

      def visit_BigDecimal(decimal) # rubocop:disable Naming/MethodName
        @emitter.scalar(decimal.to_s('F'), nil, nil, true, false, Psych::Nodes::Scalar::PLAIN)
      end
    end
  end
end
