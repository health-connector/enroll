# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module BenefitSponsors
  module Operations
    module BenefitApplications
      # This class is to get Confirmation Details of Admin action on a benefit application
      class ConfirmationDetails
        include Dry::Monads[:result, :do]

        def call(params)
          yield validate(params)
          yield fetch_benefit_application_item

          confirmation_details = yield build_confirmation_details(params)

          Success(confirmation_details)
        end

        private

        def validate(params)
          errors = []
          errors << 'benefit_sponsorship is missing' unless params.key?(:benefit_sponsorship)
          errors << 'benefit_application key is missing' unless params.key?(:benefit_application)
          errors << 'sequence_id is missing' unless params.key?(:sequence_id)

          @benefit_sponsorship = params[:benefit_sponsorship]
          @benefit_application = params[:benefit_application]
          @sequence_id = params[:sequence_id].to_i

          errors << 'Not a valid Benefit Sponsorship' unless @benefit_sponsorship.is_a?(BenefitSponsors::BenefitSponsorships::BenefitSponsorship)
          errors << 'Not a valid Benefit Application' unless @benefit_application.is_a?(BenefitSponsors::BenefitApplications::BenefitApplication)

          errors.empty? ? Success(params) : Failure(errors)
        end

        def fetch_benefit_application_item
          @item = @benefit_application.benefit_application_items.where(sequence_id: @sequence_id).first
          @item.present? ? Success(@item) : Failure("No BenefitApplicationItem found with given sequence_id")
        end

        def build_confirmation_details(params)
          if params[:errors].present?
            consruct_failure_details(params)
          else
            construct_success_details(params)
          end
        end

        def construct_success_details(_params)
          case @item.state.to_s
          when "reinstated"
            construct_reinstated_details
          when 'terminated', 'termination_pending'
            construct_terminated_details
          when 'canceled', 'retroactive_canceled'
            construct_canceled_details
          else
            {}
          end
        end

        def construct_reinstated_details
          benefit_package_ids = @benefit_application.benefit_packages.map(&:id)
          employees_updated = 0
          employee_details = @benefit_sponsorship.census_employees.active.no_timeout.inject([]) do |details, census_employee|
            enrollments = census_employee.family.hbx_enrollments.where(
              :sponsored_benefit_package_id.in => benefit_package_ids,
              :'workflow_state_transitions.transition_at'.gte => item.action_on.beginning_of_day,
              :'workflow_state_transitions.transition_at'.lte => item.action_on.end_of_day + 1.day,
              :'workflow_state_transitions.from_state' => "coverage_reinstated"
            )

            employees_updated += 1 if enrollments.present?

            details << {
              employee_name: ce.full_name,
              status: 'reinstated',
              coverage_reinstated_on: coverage_reinstated_on,
              enrollment_details: enrollments&.map(&:hbx_id)&.join(", ")
            }
          end

          payload = {
            current_status: "Active Reinstated",
            action_on: @item.action_on,
            coverage_period: @benefit_application.effective_period,
            employees_updated: employees_updated,
            employees_not_updated: @benefit_sponsorship.census_employees.active.count - employees_updated,
            employee_details: employee_details
          }

          Success(payload)
        end

        def consruct_failure_details(params)
          error_details = params[:errors].is_a?(Array) ? params[:errors].join(', ') : params[:errors]
          result = {
            confirmation_type: @item.state.to_s,
            current_status: error_details,
            action_on: TimeKeeper.datetime_of_record,
            coverage_period: @benefit_application.effective_period,
            employees_updated: 0,
            employees_not_updated: @benefit_sponsorship.census_employees.active.count
          }

          Success(result)
        end
      end
    end
  end
end