module Validations
  class UsDate
    def self.on(prop_name, allow_blank = false)
      mod = Module.new
      mod.define_singleton_method :included do |klass|
        # rubocop:disable Style/EvalWithLocation, Style/DocumentDynamicEvalDefinition
        klass.class_eval(<<-RUBYCODE)
          def __valid_US_date_property_#{prop_name}
            d_value = #{prop_name}
            begin
              Date.strptime(d_value, "%m/%d/%Y")
            rescue
              errors.add(:#{prop_name}, "invalid date: " + d_value.to_s)
            end
          end
        RUBYCODE
        # rubocop:enable Style/EvalWithLocation, Style/DocumentDynamicEvalDefinition
        klass.class_eval do
          validate "__valid_US_date_property_#{prop_name}".to_sym # rubocop:disable Lint/SymbolConversion
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
