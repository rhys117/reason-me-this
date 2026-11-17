# typed: strict

module ReasonMeThis
  class Blueprint
    # The inputs of a calculation, or the fields of each row of a list. A field of a row takes no default.
    class Fields
      #: -> void
      def initialize
        @fields = {} #: Hash[Symbol, Hash[Symbol, untyped]]
      end

      #: (Symbol, ?default: untyped, ?optional: bool, ?one_of: (Array[String] | Hash[Symbol, Symbol])?) -> void
      def number(name, default: nil, optional: false, one_of: nil) = field(name, :number, default:, optional:, one_of:)

      #: (Symbol, ?default: untyped, ?optional: bool, ?one_of: (Array[String] | Hash[Symbol, Symbol])?) -> void
      def string(name, default: nil, optional: false, one_of: nil) = field(name, :string, default:, optional:, one_of:)

      #: (Symbol, ?default: untyped, ?optional: bool) -> void
      def date(name, default: nil, optional: false) = field(name, :date, default:, optional:)

      #: (Symbol, ?default: untyped, ?optional: bool) -> void
      def time(name, default: nil, optional: false) = field(name, :time, default:, optional:)

      #: (Symbol, ?default: bool?, ?optional: bool) -> void
      def boolean(name, default: nil, optional: false) = field(name, :boolean, default:, optional:)

      # With a block, the fields each row must have. Without one, the list takes anything.
      #: (Symbol, ?default: Array[untyped]?, ?optional: bool) ?{ () [self: Fields] -> void } -> void
      def list(name, default: nil, optional: false, &block)
        row = Fields.new
        row.instance_eval(&block) if block
        field(name, :list, default:, optional:, of: (row.to_h if block))
      end

      #: -> Hash[Symbol, Hash[Symbol, untyped]]
      def to_h = @fields

      private

      #: (Symbol, Symbol, **untyped) -> void
      def field(name, type, **keys)
        @fields[name] = {type:, **keys.compact.reject { |key, held| key == :optional && !held }}
      end
    end
  end
end
