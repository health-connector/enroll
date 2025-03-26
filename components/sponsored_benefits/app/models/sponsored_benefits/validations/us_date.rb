module SponsoredBenefits
  module Validations
    class UsDate
      def self.on(prop_name, allow_blank = false)
        mod = Module.new
        mod.define_singleton_method :included do |klass|
          method_name = "__valid_US_date_property_#{prop_name}".to_sym

          klass.send(:define_method, method_name) do
            d_value = send(prop_name)
            begin
              Date.strptime(d_value, "%m/%d/%Y")
            rescue StandardError => e
              errors.add(prop_name.to_sym, "invalid date: #{d_value}, message: #{e.message}")
            end
          end

          klass.class_eval do
            validate "__valid_US_date_property_#{prop_name}".to_sym
          end

          unless allow_blank
            klass.class_eval do
              validates_presence_of prop_name.to_sym
            end
          end
        end

        mod
      end
    end
  end
end
