# frozen_string_literal: true

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
      context.each_with_object({}) do |(k,v), output| # rubocop:disable Style/HashTransformValues

        output[k] = {
          :employee_role_id => v[:employee_role].id,
          :enrollable => "true",
          :enrollment_id => v[:enrollment].id,
          :enrollment_kind => "open_enrollment",
          :family_id => v[:family].id,
          :market_kind => "employer_sponsored",
          :product_id => v[:product].id,
          :use_family_deductable => "true",
          :waivable => "true",
          :event => v[:event]
        }
      end
    end

    def can_display_health_coverage?(health_eligibility)
      if @organizer[:params][:action] == "eligible_coverage_selection"
        health_eligibility && @organizer[:params][:coverage_for] == 'health'
      else
        health_eligibility
      end
    end

    def can_display_dental_coverage?(dental_eligibility)
      if @organizer[:params][:action] == "eligible_coverage_selection"
        dental_eligibility && @organizer[:params][:coverage_for] == 'dental'
      else
        dental_eligibility
      end
    end

    def is_eligible_for_dental?(employee_role, change_plan, enrollment, effective_date)
      renewal_benefit_package = employee_role.census_employee.renewal_published_benefit_package
      active_benefit_package  = employee_role.census_employee.active_benefit_package(effective_date)

      if change_plan == "change_by_qle"
        benefit_package = fetch_benefit_package_for_sep(employee_role)
        benefit_package.present? && benefit_package.is_offering_dental?
      elsif change_plan == 'change_plan' && enrollment.present? && enrollment.is_shop?
        enrollment.sponsored_benefit_package.is_offering_dental?
      elsif employee_role.can_enroll_as_new_hire?
        active_benefit_package.present? && active_benefit_package.is_offering_dental?
      else
        current_benefit_package = (renewal_benefit_package || active_benefit_package)
        current_benefit_package.present? && current_benefit_package.is_offering_dental?
      end
    end

    def fetch_benefit_package_for_sep(employee_role)
      family = employee_role.person.primary_family
      employee_role.census_employee.benefit_package_for_date(family.earliest_effective_sep.effective_on) ||
        employee_role.benefit_package(qle: true) ||
        employee_role.census_employee.possible_benefit_package
    end
  end
end
