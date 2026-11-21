module ReasonMeThis
  # native_loop is for an engine that can run a blueprint's steps natively: it does unless this is false. The service
  # and an engine with no native loop take no notice of it.
  Configuration = Struct.new(:url, :api_key, :connection, :engine, :blueprints, :native_loop) do
    def hooks = @hooks ||= []

    def after_reasoning(&hook) = hooks << hook

    def event_handlers = @event_handlers ||= []

    def on_event(&handler) = event_handlers << handler
  end
end
