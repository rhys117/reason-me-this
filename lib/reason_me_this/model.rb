module ReasonMeThis
  module Model
    def self.included(base) = base.extend(ClassMethods)

    module ClassMethods
      def reasons(name, with:, calculation: nil, &)
        reasoned[name] = Recipe.build(with:, calculation:, &)
        {name => :run, "#{name}_explained": :explain}.each do |method, call|
          define_method(method) { |*args| reasonings[[method, args]] ||= reasoning(name, call, args) }
        end
        define_method(:"#{name}!") { |*args| reason!(name, args) }
      end

      def reasoned = @reasoned ||= superclass.respond_to?(:reasoned) ? superclass.reasoned.dup : {}
    end

    def reason_me_this_client = ReasonMeThis.default

    private

    def reasonings = @reasonings ||= {}

    def reason!(name, args)
      recipe = self.class.reasoned.fetch(name)
      explained = reasoning(name, :explain, args)
      transactionally do
        recipe.savings.each { |saving| saving.apply(self, explained) }
        save! if respond_to?(:save!)
        recipe.hooks.each { |hook| instance_exec(explained, &hook) }
        ReasonMeThis.configuration.hooks.each { |hook| hook.call(self, name, explained) }
      end
      explained
    end

    def reasoning(name, call, args)
      recipe = self.class.reasoned.fetch(name)
      reason_me_this_client.public_send(call, recipe.blueprint, instance_exec(*args, &recipe.facts), calculation: recipe.calculation)
    end

    def transactionally(&) = self.class.respond_to?(:transaction) ? self.class.transaction(&) : yield
  end
end
