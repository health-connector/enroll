# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module BenefitSponsors
  module Operations
    module BenefitApplications
      # This class is to get Confirmation Details of Admin action on a benefit application
      class ConfirmationDetails
        include Dry::Monads[:do, :result]

        def call(params)
          yield validate(params)
          yield fetch_benefit_application_item

          confirmation_details = yield build_confirmation_details(params)

          Success(confirmation_details)
        end

        private

        def validate(params)
          errors = []
          required_keys = %i[benefit_sponsorship benefit_application sequence_id]
          missing_keys = required_keys - params.keys

          errors << "#{missing_keys.join(', ')} is missing" unless missing_keys.empty?

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
          return construct_failure_details(params) if params[:errors].present?

          case @item.state.to_sym
          when :reinstate
            construct_reinstated_details
          when :terminated, :termination_pending
            construct_terminated_details
          when :canceled, :retroactive_canceled
            construct_canceled_details
          else
            Success({})
          end
        end

        def construct_terminated_details
          benefit_package_ids = @benefit_application.benefit_packages.map(&:id)
          employees_updated = 0

          employee_details = @benefit_sponsorship.census_employees.active.no_timeout.inject([]) do |details, census_employee|
            ce_details = { employee_name: census_employee.full_name, status: "terminated", coverage_updated_on: @item.action_on}

            enrollments = terminated_enrollments_for(census_employee, benefit_package_ids)
            employees_updated += 1 if enrollments.present?
            ce_details.merge!({enrollment_details: enrollments&.map(&:hbx_id)&.join(", ")})
            details << ce_details
          end

          success_payload_for(@item.state.to_s, employees_updated, employee_details)
        end

        def success_payload_for(status, employees_updated, employee_details)
          payload = {
            confirmation_type: @item.state.to_s,
            current_status: status.titleize,
            action_on: @item.action_on,
            coverage_period: @benefit_application.effective_period,
            employees_updated: employees_updated,
            employees_not_updated: @benefit_sponsorship.census_employees.active.count - employees_updated,
            employee_details: employee_details
          }

          Success(payload)
        end

        def construct_canceled_details
          benefit_package_ids = @benefit_application.benefit_packages.map(&:id)
          employees_updated = 0

          employee_details = @benefit_sponsorship.census_employees.active.no_timeout.inject([]) do |details, census_employee|
            ce_details = { employee_name: census_employee.full_name, status: "Canceled", coverage_updated_on: @item.action_on}

            enrollments = canceled_enrollments_for(census_employee, benefit_package_ids)
            employees_updated += 1 if enrollments.present?
            ce_details.merge!({enrollment_details: enrollments&.map(&:hbx_id)&.join(", ")})
            details << ce_details
          end

          success_payload_for(@item.state.to_s, employees_updated, employee_details)
        end

        def construct_reinstated_details
          benefit_package_ids = @benefit_application.benefit_packages.map(&:id)
          employees_updated = 0
          employee_details = @benefit_sponsorship.census_employees.active.no_timeout.inject([]) do |details, census_employee|
            ce_details = { employee_name: census_employee.full_name, status: "reinstated", coverage_updated_on: @item.action_on}

            enrollments = reinstated_enrollments_for(census_employee, benefit_package_ids)
            employees_updated += 1 if enrollments.present?
            ce_details.merge!({enrollment_details: enrollments&.map(&:hbx_id)&.join(", ")})
            details << ce_details
          end

          success_payload_for("Active Reinstated", employees_updated, employee_details)
        end

        def reinstated_enrollments_for(census_employee, benefit_package_ids)
          family = census_employee.family
          return [] if family.blank?

          family.active_household.hbx_enrollments.show_enrollments.where(
            :sponsored_benefit_package_id.in => benefit_package_ids,
            :'workflow_state_transitions.transition_at'.gte => @item.action_on.beginning_of_day,
            :'workflow_state_transitions.transition_at'.lte => @item.action_on.end_of_day,
            :'workflow_state_transitions.from_state' => "coverage_reinstated"
          )
        end

        def canceled_enrollments_for(census_employee, benefit_package_ids)
          family = census_employee.family
          return [] if family.blank?

          family.active_household.hbx_enrollments.show_enrollments.where(
            :sponsored_benefit_package_id.in => benefit_package_ids,
            :'workflow_state_transitions.transition_at'.gte => @item.action_on.beginning_of_day,
            :'workflow_state_transitions.transition_at'.lte => @item.action_on.end_of_day,
            :'workflow_state_transitions.to_state' => "coverage_canceled"
          )
        end

        def terminated_enrollments_for(census_employee, benefit_package_ids)
          family = census_employee.family
          return [] if family.blank?

          family.active_household.hbx_enrollments.show_enrollments.where(
            :sponsored_benefit_package_id.in => benefit_package_ids,
            :'workflow_state_transitions.transition_at'.gte => @item.action_on.beginning_of_day,
            :'workflow_state_transitions.transition_at'.lte => @item.action_on.end_of_day,
            :'workflow_state_transitions.to_state'.in => ["coverage_terminated", "coverage_termination_pending"]
          )
        end

        def construct_failure_details(params)
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