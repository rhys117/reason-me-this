module Reckoning
  class Client
    class Error < StandardError; end
    class Unauthorized < Error; end
    class NotFound < Error; end
    class StepFailed < Error; end
    class Timeout < Error; end
    class Unreachable < Error; end

    class InvalidFacts < Error
      attr_reader :problems

      def initialize(problems)
        @problems = problems
        super("the facts have problems: #{problems.join('; ')}")
      end
    end
  end
end
