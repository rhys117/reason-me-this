module ReasonMeThis
  module Model
    def self.included(base) = base.extend(ClassMethods)

    module ClassMethods
      def reasons(name, with:, calculation: nil, &facts)
        {name => :run, "#{name}_explained": :explain}.each do |method, call|
          define_method(method) do |*args|
            reasonings[[method, args]] ||= reason_me_this_client.public_send(call, with, instance_exec(*args, &facts), calculation:)
          end
        end
      end
    end

    def reason_me_this_client = ReasonMeThis.default

    private

    def reasonings = @reasonings ||= {}
  end
end
