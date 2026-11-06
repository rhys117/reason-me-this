module ReasonMeThis
  module Model
    def self.included(base) = base.extend(ClassMethods)

    module ClassMethods
      def reasons(name, with:, calculation: nil, &)
        reasoned[name] = Recipe.build(with:, calculation:, &)
        keep_receipts if reasoned[name].receipts
        {name => :run, "#{name}_explained": :explain}.each do |method, call|
          define_method(method) { |*args| reasonings[[method, args]] ||= reasoning(self.class.reasoned.fetch(name), call, args) }
        end
        define_method(:"#{name}!") { |*args| reason!(name, args) }
      end

      def reasoned = @reasoned ||= superclass.respond_to?(:reasoned) ? superclass.reasoned.dup : {}

      def keep_receipts
        require 'reason_me_this/receipt'
        has_many :reason_me_this_receipts, as: :record, class_name: 'ReasonMeThis::Receipt' unless reflect_on_association(:reason_me_this_receipts)
      end
    end

    def reason_me_this_client = ReasonMeThis.default

    private

    def reasonings = @reasonings ||= {}

    def reason!(name, args)
      recipe = self.class.reasoned.fetch(name)
      facts = instance_exec(*args, &recipe.facts)
      explained = reason_me_this_client.explain(recipe.blueprint, facts, calculation: recipe.calculation)
      transactionally do
        recipe.savings.each { |saving| saving.apply(self, explained) }
        save! if respond_to?(:save!)
        recipe.hooks.each { |hook| instance_exec(explained, &hook) }
        ReasonMeThis.configuration.hooks.each { |hook| hook.call(self, name, explained) }
        keep_receipt(recipe, name, facts, explained) if recipe.receipts
      end
      committed { announce(recipe, name, explained) }
      explained
    end

    def announce(recipe, name, explained)
      explained.events.each do |event|
        recipe.handlers.fetch(event.name, []).each { |handler| instance_exec(event, explained, &handler) }
        ReasonMeThis.configuration.event_handlers.each { |handler| handler.call(self, name, event) }
      end
    end

    def reasoning(recipe, call, args)
      reason_me_this_client.public_send(call, recipe.blueprint, instance_exec(*args, &recipe.facts), calculation: recipe.calculation)
    end

    def keep_receipt(recipe, name, facts, explained)
      reason_me_this_receipts.create!(reasoning: name, blueprint: recipe.blueprint, version: explained.version, calculation: recipe.calculation,
                                      facts: Values.text(facts), outputs: Values.text(explained.outputs.to_h), steps: Values.text(explained.steps))
    end

    def transactionally(&) = self.class.respond_to?(:transaction) ? self.class.transaction(&) : yield

    # Inside a transaction the caller opened, after_all_transactions_commit waits for it to commit, and never
    # runs if it rolls back. Outside one, or without Active Record, the block runs now.
    def committed(&)
      defined?(ActiveRecord) && ActiveRecord.respond_to?(:after_all_transactions_commit) ? ActiveRecord.after_all_transactions_commit(&) : yield
    end
  end
end
