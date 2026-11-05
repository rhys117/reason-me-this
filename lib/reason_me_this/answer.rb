module ReasonMeThis
  class Answer
    def initialize(outputs)
      @outputs = Values.read(outputs)
    end

    def [](name) = @outputs[name.to_sym]

    def to_h = @outputs

    def method_missing(name, *args)
      args.empty? && @outputs.key?(name) ? @outputs[name] : super
    end

    def respond_to_missing?(name, include_private = false) = @outputs.key?(name) || super
  end
end
