module ReasonMeThis
  Configuration = Struct.new(:url, :api_key, :connection) do
    def hooks = @hooks ||= []

    def after_reasoning(&hook) = hooks << hook
  end
end
