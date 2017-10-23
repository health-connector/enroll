module Observers
  class NoticeObserver < Observer

    PLANYEAR_NOTICE_EVENTS = [
      :renewal_application_created,
      :initial_application_submitted,
      :renewal_application_submitted,
      :renewal_application_autosubmitted,
      :renewal_application_enrolling,
      :ineligible_initial_application_submitted,
      :ineligible_renewal_application_submitted,
      :open_enrollment_began,
      :open_enrollment_ended,
      :application_denied,
      :renewal_application_denied
    ]
  
    def plan_year_update(new_model_event)
      raise ArgumentError.new("expected ModelEvents::ModelEvent") unless new_model_event.is_a?(ModelEvents::ModelEvent)

      if PLANYEAR_NOTICE_EVENTS.include?(new_model_event.event_key)
        plan_year = new_model_event.klass_instance
        
        if new_model_event.event_key == :renewal_application_denied
          errors = plan_year.enrollment_errors

            trigger_notice(recipient: plan_year.employer_profile, event_object: plan_year, notice_event: "renewal_employer_ineligibility_notice")

            plan_year.employer_profile.census_employees.non_terminated.each do |ce|
              if ce.employee_role.present?
                trigger_notice(recipient: ce.employee_role, event_object: plan_year, notice_event: "employee_renewal_employer_ineligibility_notice")
              end
            end
        end
        
        if new_model_event.event_key == :renewal_application_submitted
          trigger_notice(recipient: plan_year.employer_profile, event_object: plan_year, notice_event: "renewal_application_published")
        end

        if new_model_event.event_key == :renewal_application_created
          trigger_notice(recipient: plan_year.employer_profile, event_object: plan_year, notice_event: "renewal_application_created")
        end

        if new_model_event.event_key == :renewal_application_enrolling
          plan_year.employer_profile.census_employees.non_terminated.each do |ce|
            ce.renewal_benefit_group_assignment.each do |bg|
              if bg.hbx_enrollment.aasm_state.include?('renewing_waived')
                trigger_notice(recipient: ce.employee_role, event_object: plan_year, notice_event: "renewal_employee_open_enrollment_unenrolled")
              end
            end
          end
        end

        if new_model_event.event_key == :ineligible_renewal_application_submitted
          if plan_year.application_eligibility_warnings.include?(:primary_office_location)
            trigger_notice(recipient: plan_year.employer_profile, event_object: plan_year, notice_event: "employer_renewal_eligibility_denial_notice")

            plan_year.employer_profile.census_employees.non_terminated.each do |ce|
              trigger_notice(recipient: ce.employee_role, event_object: plan_year, notice_event: "termination_of_employers_health_coverage")
            end
          end
        end
      end
    end

    def employer_profile_update; end
    def hbx_enrollment_update; end
    def census_employee_update; end
  end
end