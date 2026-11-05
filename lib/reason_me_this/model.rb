module ReasonMeThis
  module Model
    def self.included(base) = base.extend(ClassMethods)

    module ClassMethods
      def reasons(name, with:, calculation: nil, &facts)
        reasoned[name] = {with:, calculation:, facts:}
        {name => :run, "#{name}_explained": :explain}.each do |method, call|
          define_method(method) do |*args|
            reasonings[[method, args]] ||= reason_me_this_client.public_send(call, with, instance_exec(*args, &facts), calculation:)
          end
        end
        define_method(:"#{name}!") { |*args| reason!(name, args) }
      end

      def saves(name, **columns) = savings[name] << columns

      def reasoned = @reasoned ||= {}

      def savings = @savings ||= Hash.new { |all, name| all[name] = [] }
    end

    def reason_me_this_client = ReasonMeThis.default

    private

    def reasonings = @reasonings ||= {}

    def reason!(name, args)
      how = self.class.reasoned.fetch(name)
      explained = reason_me_this_client.explain(how[:with], instance_exec(*args, &how[:facts]), calculation: how[:calculation])
      transactionally do
        self.class.savings[name].each { |columns| columns.each { |column, path| public_send(:"#{column}=", explained.at(path)) } }
        save! if respond_to?(:save!)
      end
      explained
    end

    def transactionally(&) = self.class.respond_to?(:transaction) ? self.class.transaction(&) : yield
  end
end
