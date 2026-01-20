# frozen_string_literal: true

module Validations
  class UsDate
    def self.on(prop_name, allow_blank: false)
      Module.new do
        define_singleton_method :included do |klass|

          method_name = :"__valid_US_date_property_#{prop_name}"

          klass.define_method(method_name) do
            d_value = public_send(prop_name)

            return if allow_blank && d_value.blank?
            return if d_value.blank?

            begin
              Date.strptime(d_value, "%m/%d/%Y")
            rescue ArgumentError
              errors.add(prop_name, "invalid date: #{d_value}")
            end
          end

          klass.validate method_name
          klass.validates_presence_of prop_name unless allow_blank
        end
      end
    end
  end
end
