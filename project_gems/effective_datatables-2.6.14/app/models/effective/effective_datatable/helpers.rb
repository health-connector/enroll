module Effective
  module EffectiveDatatable
    module Helpers
      # When we order by Array, it's already a string.
      # This gives us a mechanism to sort numbers as numbers
      def convert_to_column_type(table_column, value)
        value = ActionView::Base.full_sanitizer.sanitize(value) if value.html_safe? && value.is_a?(String) && value.start_with?('<')

        case table_column[:type]
        when :number, :price, :decimal, :float, :percentage
          unless value.is_a?(Numeric)
            begin
              value.to_s.gsub(/[^0-9|.]/, '').to_f
            rescue StandardError
              0.00
            end
          end
        when :integer
          unless value.is_a?(Integer)
            begin
              value.to_s.gsub(/\D/, '').to_i
            rescue StandardError
              0
            end
          end
        else
           # Do nothing
        end || value
      end
    end
  end
end
