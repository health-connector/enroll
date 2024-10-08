module BenefitSponsors
  module Services
    class BenefitApplicationService
      attr_reader :benefit_application_factory, :benefit_sponsorship

      def initialize(factory_kind = BenefitSponsors::BenefitApplications::BenefitApplicationFactory)
        @benefit_application_factory = factory_kind
      end

      # load defaults from models
      def load_default_form_params(form)
        form
      end

      def load_form_metadata(form)
        find_benefit_sponsorship(form)
        form.has_active_ba = has_an_active_ba? if form.admin_datatable_action
        form.start_on_options = filter_start_on_options(form)
      end

      def filter_start_on_options(form)
        schedular = BenefitSponsors::BenefitApplications::BenefitApplicationSchedular.new
        schedular.start_on_options_with_schedule(form.admin_datatable_action)
      end

      def load_form_params_from_resource(form)
        benefit_application = find_model_by_id(form.id)
        load_benefit_packages_form(form, benefit_application)
        attributes_to_form_params(benefit_application, form)
      end

      def load_benefit_packages_form(form, benefit_application)
        benefit_application.benefit_packages.each do |benefit_package|
          form.benefit_packages << BenefitSponsors::Forms::BenefitPackageForm.for_edit({id: benefit_package.id.to_s, benefit_application_id: benefit_application.id.to_s}, false)
        end
      end

      def save(form)
        model_attributes = form_params_to_attributes(form)
        find_benefit_sponsorship(form)
        create_or_cancel_draft_ba(form, model_attributes)
      end

      def has_an_active_ba?
        bas = benefit_sponsorship.benefit_applications
        bas.active_states_per_dt_action.present?
      end

      def can_create_draft_ba?(form)
        bas = benefit_sponsorship.benefit_applications
        return true unless bas.present?

        term_pending_bas = bas.termination_pending
        if term_pending_bas.present?
          !can_create_draft_for_tp?(term_pending_bas, form)
        else
          bas.active_states_per_dt_action.present? || bas.canceled.present? || bas.draft.present?
        end
      end

      def can_create_draft_for_tp?(bas, form)
        start_on_date = Date.strptime(form.start_on, "%m/%d/%Y")
        bas.any? { |ba| ba.effective_period.cover?(start_on_date)}
      end

      def has_overlap_application?(model_attributes)
        terminated_bas = @benefit_sponsorship.benefit_applications.terminated_or_termination_pending +
                         @benefit_sponsorship.benefit_applications.enrollment_eligible +
                         @benefit_sponsorship.benefit_applications.enrollment_closed
        terminated_bas.any? {|ba| ba.effective_period.cover?(model_attributes[:effective_period].min)}
      end

      def create_or_cancel_draft_ba(form, model_attributes)
        if form.admin_datatable_action && !can_create_draft_ba?(form) || has_overlap_application?(model_attributes)
          form.errors.add(:base, 'Existing plan year with overlapping coverage exists')
          [false, nil]
        else
          benefit_application = benefit_application_factory.call(benefit_sponsorship, model_attributes)
          save_result, persisted_object = store(form, benefit_application)
          if save_result
            if form.admin_datatable_action
              terminate_active_applications(persisted_object)
            elsif benefit_sponsorship.may_revert_to_applicant? && !benefit_sponsorship.applicant?
              benefit_sponsorship.revert_to_applicant!
            end
            cancel_unwanted_applications(persisted_object, admin_datatable_action: form.admin_datatable_action)
          end
          [save_result, persisted_object]
        end
      end

      def applications_for_cancel(benefit_application, admin_datatable_action)
        applications = benefit_sponsorship.benefit_applications.draft_and_exception.reject { |existing_application| existing_application == benefit_application }
                        # + benefit_sponsorship.benefit_applications.enrollment_ineligible.reject(&:is_renewing?)
        applications += benefit_sponsorship.benefit_applications.enrolling.to_a + benefit_sponsorship.benefit_applications.enrollment_eligible.to_a if admin_datatable_action
        applications
      end

      def cancel_unwanted_applications(benefit_application, admin_datatable_action: false)
        applications_for_cancel(benefit_application, admin_datatable_action).each do |application|
          application.cancel! if application.may_cancel?
        end
      end

      def terminate_active_applications(new_ba)
        termination_date = new_ba.start_on.prev_day
        applications_for_termination = benefit_sponsorship.benefit_applications.where(aasm_state: :active).select { |ba| ba.effective_period.cover?(new_ba.start_on) }

        applications_for_termination.each do |application|
          enrollment_service = BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(application)
          if termination_date < application.start_on
            enrollment_service.cancel(true)
          else
            enrollment_service.schedule_termination(termination_date, TimeKeeper.date_of_record, "voluntary", "Other", true)
          end
        end
      end

      def revert(form)
        benefit_application = find_model_by_id(form.id)
        enrollment_service = BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(benefit_application)
        saved_result, benefit_application, errors = enrollment_service.revert_application

        if errors.present?
          errors.each do |k, v|
            form.errors.add(k, v)
          end
        end
        [saved_result, benefit_application]
      end

      def force_submit_application_with_eligibility_errors(form)
        benefit_application = find_model_by_id(form.id)
        enrollment_service = BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(benefit_application)
        enrollment_service.force_submit_application_with_eligibility_errors
        [true, benefit_application]
      end

      def submit_application(form)
        benefit_application = find_model_by_id(form.id)
        enrollment_service = BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(benefit_application)
        saved_result, benefit_application, errors = enrollment_service.submit_application

        if errors.present?
          errors.each do |k, v|
            form.errors.add(k, v)
          end
        end
        [saved_result, benefit_application]
      end

      def update(form)
        benefit_application = find_model_by_id(form.id)
        model_attributes = form_params_to_attributes(form).except(:effective_period)
        benefit_application.assign_attributes(model_attributes)
        store(form, benefit_application)
      end

      # TODO: Test this query for benefit applications cca/dc
      # TODO: Change it back to find once find method on BenefitApplication is fixed.
      def find_model_by_id(id)
        BenefitSponsors::BenefitApplications::BenefitApplication.find(id)
      end

      # TODO: Change it back to find once find method on BenefitSponsorship is fixed.
      def find_benefit_sponsorship(form)
        return @benefit_sponsorship if defined? @benefit_sponsorship
        @benefit_sponsorship = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(id: form.benefit_sponsorship_id).first
      end

      def attributes_to_form_params(benefit_application,form)
        form.attributes = {
          start_on: format_date_to_string(benefit_application.effective_period.min),
          end_on: format_date_to_string(benefit_application.effective_period.max),
          open_enrollment_start_on: format_date_to_string(benefit_application.open_enrollment_period.min),
          open_enrollment_end_on: format_date_to_string(benefit_application.open_enrollment_period.max),
          fte_count: benefit_application.fte_count,
          pte_count: benefit_application.pte_count,
          msp_count: benefit_application.msp_count
        }
      end

      def form_params_to_attributes(form)
        {
          effective_period: (format_string_to_date(form.start_on)..format_string_to_date(form.end_on)),
          open_enrollment_period: (format_string_to_date(form.open_enrollment_start_on)..format_string_to_date(form.open_enrollment_end_on)),
          fte_count: form.fte_count.to_i,
          pte_count: form.pte_count.to_i,
          msp_count: form.msp_count.to_i
        }
      end

      #TODO: FIX date format
      def format_string_to_date(date)
        if date.split('/').first.size == 2
          Date.strptime(date,"%m/%d/%Y")
        elsif date.split('-').first.size == 4
          Date.strptime(date,"%Y-%m-%d")
        end
      end

      def format_date_to_string(date)
        date.to_date.to_s
      end

      def store(form, benefit_application)
        valid_according_to_factory = benefit_application_factory.validate(benefit_application)
        if valid_according_to_factory
          benefit_sponsorship = benefit_application.benefit_sponsorship || find_benefit_sponsorship(form)
          # TODO: enable it for new domain operations
          benefit_application.benefit_sponsor_catalog = benefit_sponsorship.benefit_sponsor_catalog_for(benefit_application.start_on.to_date)
          # assign_rating_and_service_area(benefit_application)
        else
          map_errors_for(benefit_application, onto: form)
          return [false, nil]
        end

        if save_successful = benefit_application.save
          catalog = benefit_application.benefit_sponsor_catalog
          catalog.benefit_application = benefit_application
          catalog.save
        else
          map_errors_for(benefit_application, onto: form)
          return [false, nil]
        end

        [true, benefit_application]
      end

      # #TODO: FIX this method once countzips are loaded
      # def assign_rating_and_service_area(benefit_application)
      #   benefit_application.recorded_rating_area = benefit_application.resolve_rating_area
      #   benefit_application.recorded_service_areas = benefit_application.resolve_service_areas
      # end

      def map_errors_for(benefit_application, onto:)
        benefit_application.errors.each do |att, err|
          onto.errors.add(map_model_error_attribute(att), err)
        end
      end

      # We can cheat here because our form and our model are so
      # close together - normally this will be more complex
      def map_model_error_attribute(model_attribute_name)
        model_attribute_name
      end

    end
  end
end
