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
          output = yield reinstate_census_employees
          yield renew_benefit_application
          yield renew_enrollments

          Success(output)
        end

        private

        def validate(params)
          return Failure('Missing Key(s).') unless params.key?(:benefit_application) || params.key?(:transmit_to_carrier) || params.key?(:reinstate_on)

          @benefit_application = params[:benefit_application]
          @transmit_to_carrier = params[:transmit_to_carrier]
          @reinstate_on = params[:reinstate_on]
          @current_user = params[:current_user]
          return Failure('Not a valid Benefit Application') unless @benefit_application.is_a?(BenefitSponsors::BenefitApplications::BenefitApplication)

          @sequence_id = @benefit_application.benefit_application_items.max(:sequence_id)

          Success(params)
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
          @benefit_application.activate_reinstate!({ disable_callbacks: true })

          Success()
        rescue StandardError => e
          Failure("Failed with error: #{e}")
        end

        def reinstate_census_employees
          benefit_package_ids = @benefit_application.benefit_packages.map(&:id)
          item = @benefit_application.benefit_application_items.find_by(sequence_id: @sequence_id)
          coverage_reinstated_on = @benefit_application.latest_benefit_application_item.effective_period.min

          output = CensusEmployee.eligible_for_reinstate(@benefit_application, @reinstate_on).no_timeout.inject([]) do |result, census_employee|
            benefit_group_assignment = census_employee.benefit_group_assignments.where(:benefit_package_id.in => benefit_package_ids).order_by(:created_at.desc).first

            benefit_group_assignment.update_attributes!(end_on: nil)


            census_employee.family.active_household.hbx_enrollments.where(
              :sponsored_benefit_package_id.in => benefit_package_ids,
              :aasm_state.in => ["coverage_termination_pending", "coverage_terminated", "coverage_canceled"],
              :'workflow_state_transitions.transition_at'.gte => item.created_at
            ).each do |hbx_enrollment|
              hbx_enrollment.reinstate_enrollment!({ disable_callbacks: true })
              hbx_enrollment.begin_coverage!({ disable_callbacks: true })
            end
            result << {
              employee_name: census_employee.full_name,
              status: 'reinstated',
              coverage_reinstated_on: coverage_reinstated_on,
              error_details: 'N/A'
            }
            result
          rescue StandardError => e
            Rails.logger.error "Error while reinstating benefit group assignment for #{census_employee.full_name}(#{census_employee.id}) #{e}"
            result << {
              employee_name: census_employee.full_name,
              status: 'reinstate failed',
              coverage_reinstated_on: nil,
              error_details: e
            }
            result
          end

          Success(output)
        end

        def renew_benefit_application
          Success()
        end

        def renew_enrollments
          Success()
        end
      end
    end
  end
end
