module Insured
  module ShoppingsHelper
    def disable_continuous_purchase?(enrollables, hbx_enrollments, options = {})
      return false if enrollables.all?(true)

      output = hbx_enrollments.collect do |enrollment|
        enrollment.can_select_coverage?(qle: options[:qle])
      end

      output.all?(true) ? false : true
    end

    def build_hash_to_checkout(context)
      context.each_with_object({}) do |(k,v), output|

        output[k] = {
          :employee_role_id => v[:employee_role].id,
          :enrollable => "true",
          :enrollment_id => v[:enrollment].id,
          :enrollment_kind => "open_enrollment",
          :family_id => v[:family].id,
          :market_kind => "employer_sponsored",
          :product_id => v[:product].id,
          :use_family_deductable => "true",
          :waivable => "true"
        }
      end
    end
  end
end

