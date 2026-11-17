# typed: false

require 'bigdecimal'
require 'yaml'

module ReasonMeThis
  class Blueprint
    # Reads and writes a blueprint's document as the YAML a blueprint file holds. Written, a decimal as the exact number it is, and a
    # value used twice in full both times, since a blueprint may not have an alias.
    class Yaml < Psych::Visitors::YAMLTree
      class Exact < Psych::ScalarScanner
        def tokenize(text)
          read = super
          read.is_a?(Float) && text.match?(/\A[-+]?\d[\d_]*\.\d+\z/) ? BigDecimal(text.delete('_')) : read
        end
      end

      # Reads a blueprint file's document as the engine does: decimals exactly, dates as dates, and every key as text,
      # so that on, yes and no are names and never true or false.
      def self.read(yaml)
        tree = Psych.parse(yaml) or return
        tree.grep(Psych::Nodes::Mapping).each { |mapping| mapping.children.each_slice(2) { |key, _held| key.quoted = true if key.scalar? } }
        loader = Psych::ClassLoader::Restricted.new(%w[Date Time], [])
        Psych::Visitors::ToRuby.new(Exact.new(loader), loader).accept(tree)
      end

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
