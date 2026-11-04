module Reckoning
  class Client
    module Model
      def self.included(base) = base.extend(ClassMethods)

      module ClassMethods
        def reckons(name, with:, calculation: nil, &facts)
          {name => :run, "#{name}_explained": :explain}.each do |method, call|
            define_method(method) do |*args|
              reckonings[[method, args]] ||= reckoning_client.public_send(call, with, instance_exec(*args, &facts), calculation:)
            end
          end
        end
      end

      def reckoning_client = Client.default

      private

      def reckonings = @reckonings ||= {}
    end
  end
end
