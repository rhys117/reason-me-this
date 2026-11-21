module ReasonMeThis
  # native_loop is for an engine that can run a blueprint's steps natively: it does unless this is false, and with
  # :strict it refuses a blueprint it cannot run natively rather than run it another way. The service and an engine
  # with no native loop take no notice of it.
  Configuration = Struct.new(:url, :api_key, :connection, :engine, :blueprints, :native_loop) do
    # What the setting comes to: on, unless a host said otherwise.
    def native_loop = self[:native_loop].nil? || self[:native_loop]

    # Told, by an engine with a native loop, what it ran another way and why: {kind:, blueprint:, version:, reason:}.
    def on_fallback(&handler) = @fallback = handler

    def fallback = @fallback

    def hooks = @hooks ||= []

    def after_reasoning(&hook) = hooks << hook

    def event_handlers = @event_handlers ||= []

    def on_event(&handler) = event_handlers << handler
  end
end
