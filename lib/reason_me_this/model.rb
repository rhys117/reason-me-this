module ReasonMeThis
  module Model
    def self.included(base) = base.extend(ClassMethods)

    module ClassMethods
      def reasons(name, with:, calculation: nil, &facts)
        reasoned[name] = {with:, calculation:, facts:}
        {name => :run, "#{name}_explained": :explain}.each do |method, call|
          define_method(method) { |*args| reasonings[[method, args]] ||= reasoning(name, call, args) }
        end
        define_method(:"#{name}!") { |*args| reason!(name, args) }
      end

      def saves(name, **) = savings[name] << Saving.of(**)

      def reasoned = @reasoned ||= {}

      def savings = @savings ||= Hash.new { |all, name| all[name] = [] }
    end

    def reason_me_this_client = ReasonMeThis.default

    private

    def reasonings = @reasonings ||= {}

    def reason!(name, args)
      explained = reasoning(name, :explain, args)
      transactionally do
        self.class.savings[name].each { |saving| saving.apply(self, explained) }
        save! if respond_to?(:save!)
      end
      explained
    end

    def reasoning(name, call, args)
      how = self.class.reasoned.fetch(name)
      reason_me_this_client.public_send(call, how[:with], instance_exec(*args, &how[:facts]), calculation: how[:calculation])
    end

    def transactionally(&) = self.class.respond_to?(:transaction) ? self.class.transaction(&) : yield
  end
end
