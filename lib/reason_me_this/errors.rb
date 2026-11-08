module ReasonMeThis
  class Error < StandardError; end
  class Unauthorized < Error; end
  class NotFound < Error; end
  class Gone < Error; end
  class StepFailed < Error; end
  class Timeout < Error; end
  class Unreachable < Error; end
  class InvalidSignature < Error; end

  class Refused < Error
    attr_reader :report

    def initialize(report)
      @report = report
      super(message)
    end

    def problems = report.fetch(:problems, [])
  end

  class InvalidFacts < Refused
    def message = "the facts have problems: #{problems.join('; ')}"
  end

  class Rejected < Refused
    def message
      failed = "#{report[:failed]} cases failed" if report[:failed].to_i.positive?
      "the definition was not accepted: #{[*problems, failed].compact.join('; ')}"
    end
  end
end
