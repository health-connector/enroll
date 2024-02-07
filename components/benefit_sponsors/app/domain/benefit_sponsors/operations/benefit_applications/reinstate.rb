# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module BenefitSponsors
  module Operations
    module BenefitApplications
      # This class reinstates a benefit application
      class Reinstate
        include Dry::Monads[:result, :do]

        # @param [ BenefitSponsors::BenefitApplications::BenefitApplication ] benefit_application
        def call(params)
          yield validate(params)
          yield reinstate_benefit_application
          yield reinstate_census_employees
          yield renew_benefit_application

          Success()
        end

        private

        def validate(params)
          errors = []
          errors << 'benefit_application is missing' unless params.key?(:benefit_application)
          errors << 'transmit_to_carrier key is missing' unless params.key?(:transmit_to_carrier)
          errors << 'reinstate_on is missing' unless params.key?(:reinstate_on)

          @benefit_application = params[:benefit_application]
          @transmit_to_carrier = params[:transmit_to_carrier]
          @reinstate_on = params[:reinstate_on]
          @current_user = params[:current_user]
          if @benefit_application.is_a?(BenefitSponsors::BenefitApplications::BenefitApplication)
            @sequence_id = @benefit_application.benefit_application_items.max(:sequence_id)
            errors << "Reinstate failed due to overlapping benefit applications" if any_overlapping_application?
            errors << "Reinstate can only occur on current year benefit application" if is_prev_year_application?
            errors << "Reinstate on will result gap in coverage which is not allowed" if incorrect_reinstate_on?
          else
            errors << 'Not a valid Benefit Application'
          end

          errors.compact.empty? ? Success(params) : Failure(errors)
        end

        def any_overlapping_application?
          benefit_sponsorship = @benefit_application.benefit_sponsorship
          aasm_states = ::BenefitSponsors::BenefitApplications::BenefitApplication::APPPROVED_AND_TERMINATED_STATES + [:draft]

          benefit_sponsorship.benefit_applications.where(
            :_id.ne => @benefit_application.id,
            :aasm_state.in => aasm_states
          ).any? do |application|
            @benefit_application.initial_effective_period.cover?(application.start_on)
          end
        end

        def is_prev_year_application?
          return true if TimeKeeper.date_of_record > @benefit_application.earliest_benefit_application_item.effective_period.max
        end

        def incorrect_reinstate_on?
          application_eligible_reinstate_on = @benefit_application.retroactive_canceled? ? @benefit_application.start_on : (@benefit_application.end_on + 1.day)
          return true if application_eligible_reinstate_on != @reinstate_on
        end

        def reinstate_benefit_application
          return Failure("Cannot reinstate #{@benefit_application.aasm_state} benefit application") unless @benefit_application.may_reinstate?

          item = @benefit_application.earliest_benefit_application_item
          effective_period = @reinstate_on..item.effective_period.max

          @benefit_application.benefit_application_items.create!(
            sequence_id: @sequence_id + 1,
            effective_period: effective_period,
            action_type: :correction,
            action_kind: 'reinstate',
            state: :reinstate,
            updated_by: @current_user&.id
          )
          @benefit_application.reinstate!
          @benefit_application.activate_reinstate!({ disable_callbacks: true, edi: true })
          @benefit_application.reload

          Success()
        rescue StandardError => e
          Failure("Failed with error: #{e}")
        end

        def reinstate_census_employees
          benefit_package_ids = @benefit_application.benefit_packages.map(&:id)
          item = @benefit_application.benefit_application_items.find_by(sequence_id: @sequence_id)
          application_term_date = item.effective_period.max

          if item.state == :retroactive_canceled
            is_retroactive_canceled = true
            application_term_date = item.effective_period.min
          end

          CensusEmployee.eligible_for_reinstate(@benefit_application, @reinstate_on).no_timeout.each do |census_employee|
            benefit_group_assignment = census_employee.benefit_group_assignments.where(:benefit_package_id.in => benefit_package_ids).order_by(:created_at.desc).first

            benefit_group_assignment.update_attributes!(end_on: nil)

            household = census_employee.family.active_household
            enrollments = household.hbx_enrollments.where(
              :sponsored_benefit_package_id.in => benefit_package_ids,
              :aasm_state.in => ["coverage_termination_pending", "coverage_terminated", "coverage_canceled"],
              :'workflow_state_transitions.transition_at'.gte => item.created_at
            )

            enrollments.select {|enr| enr.terminated_on.blank? || enr.terminated_on == application_term_date }.each do |hbx_enrollment|
              effective_on = if is_retroactive_canceled
                               hbx_enrollment.effective_on
                             elsif hbx_enrollment.effective_on > @reinstate_on
                               hbx_enrollment.effective_on
                             else
                               @reinstate_on
                             end
              reinstate_enrollment = clone_enrollment(hbx_enrollment, effective_on)
              reinstate_enrollment.household = household
              reinstate_enrollment.save!

              handle_coverage(hbx_enrollment, reinstate_enrollment)
            end
          rescue StandardError => e
            Rails.logger.error "Error while reinstating benefit group assignment for #{census_employee.full_name}(#{census_employee.id}) #{e}"
          end

          Success()
        end

        def handle_coverage(hbx_enrollment, reinstate_enrollment)
          if hbx_enrollment.waiver_reason.present? || hbx_enrollment.product_id.blank?
            reinstate_enrollment.waive_coverage!
          else
            reinstate_enrollment.begin_coverage!({ disable_callbacks: true })
            reinstate_enrollment.begin_coverage!({ disable_callbacks: true }) if TimeKeeper.date_of_record >= reinstate_enrollment.effective_on && reinstate_enrollment.may_begin_coverage?

            prev_terminated_on = hbx_enrollment.prev_terminated_on
            if prev_terminated_on.present?
              if prev_terminated_on >= TimeKeeper.date_of_record
                reinstate_enrollment.schedule_coverage_termination!(hbx_enrollment.prev_terminated_on)
              else
                reinstate_enrollment.terminate_coverage!(hbx_enrollment.prev_terminated_on)
              end
            end

            reinstate_enrollment.notify_of_coverage_start(true)
          end
        end

        def renew_benefit_application
          months_prior_to_effective = Settings.aca.shop_market.renewal_application.earliest_start_prior_to_effective_on.months.abs
          renewal_day = (@benefit_application.latest_benefit_application_item.effective_period.max + 1.day).to_date - months_prior_to_effective.months
          return Success() if TimeKeeper.date_of_record < renewal_day

          service = ::BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(@benefit_application)
          success, _application, message = service.renew_application

          Rails.logger.error "Error while renewing benefit application #{@benefit_application.id}: #{message}" unless success

          Success()
        end

        def clone_enrollment(hbx_enrollment, effective_on)
          HbxEnrollment.new(enrollment_attrs(hbx_enrollment, effective_on))
        end

        def enrollment_attrs(hbx_enrollment, effective_on)
          attrs = hbx_enrollment.serializable_hash.deep_symbolize_keys.except(
            :_id, :created_at, :updated_at, :hbx_id, :effective_on, :aasm_state,
            :terminated_on, :terminate_reason,:termination_submitted_on, :hbx_enrollment_members, :workflow_state_transitions
          )

          attrs.merge!({
                         aasm_state: 'coverage_reinstated',
                         effective_on: effective_on,
                         predecessor_enrollment_id: hbx_enrollment.id,
                         hbx_enrollment_members: hbx_enrollment_members_params(hbx_enrollment)
                       })
        end

        def hbx_enrollment_members_params(hbx_enrollment)
          hbx_enrollment.hbx_enrollment_members.inject([]) do |result, member|
            result << member.serializable_hash.deep_symbolize_keys.except(:_id, :created_at, :updated_at, :coverage_end_on).merge!({ eligibility_date: @reinstate_on })
            result
          end
        end
      end
    end
  end
end
