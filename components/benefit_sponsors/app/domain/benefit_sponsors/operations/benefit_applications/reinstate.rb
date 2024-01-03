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
          yield reinstate_benefit_group_assignments
          yield reinstate_enrollments
          yield activate_enrollment # TODO: check if this is required
          yield renew_benefit_application
          yield renew_enrollments

          Success() # TODO: send json payload based on requirements
        end

        private

        def validate(params)
          return Failure('Missing Key(s).') unless params.key?(:benefit_application) || params.key?(:transmit_to_carrier) || params.key?(:reinstate_on)

          @benefit_application = params[:benefit_application]
          @transmit_to_carrier = params[:transmit_to_carrier]
          @reinstate_on = params[:reinstate_on]
          @current_user = params[:current_user]
          return Failure('Not a valid Benefit Application') unless @benefit_application.is_a?(BenefitSponsors::BenefitApplications::BenefitApplication)

          Success(params)
        end

        def reinstate_benefit_application
          return Failure("Cannot reinstate #{@benefit_application.aasm_state} benefit application") unless @benefit_application.may_reinstate?

          sequence_id = @benefit_application.benefit_application_items.max(:sequence_id) + 1
          item = @benefit_application.earliest_benefit_application_item
          effective_period = @reinstate_on..item.effective_period.max

          @benefit_application.benefit_application_items.create!(
            sequence_id: sequence_id,
            effective_period: effective_period,
            action_type: :correction,
            action_kind: 'reinstate',
            state: :reinstate,
            updated_by: @current_user&.id
          )
          @benefit_application.reinstate!

          Success()
        rescue StandardError => e
          Failure("Failed with error: #{e}")
        end

        # TODO: check if we can adjust requirements & do this async
        def reinstate_benefit_group_assignments
          benefit_package_ids = @benefit_application.benefit_packages.map(&:id)
          CensusEmployee.eligible_for_reinstate(@benefit_application, @reinstate_on).no_timeout.each do |census_employee|
            benefit_group_assignment = census_employee.benefit_group_assignments.where(:benefit_package_id.in => benefit_package_ids).order_by(:created_at.desc).first

            benefit_group_assignment.update_attributes!(end_on: nil)
          rescue StandardError => e
            # TODO: (?) based on requirements we need to handle these errors
            Rails.logger.error "Error while reinstating benefit group assignment for #{census_employee.full_name}(#{census_employee.id}) #{e}"
          end

          Success()
        end

        def reinstate_enrollments
          Success()
        end

        def activate_enrollment
          Success()
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
