module ReasonMeThis
  Configuration = Struct.new(:url, :api_key, :connection, :engine, :blueprints) do
    def hooks = @hooks ||= []

    def after_reasoning(&hook) = hooks << hook

    def event_handlers = @event_handlers ||= []

    def on_event(&handler) = event_handlers << handler
  end
end
