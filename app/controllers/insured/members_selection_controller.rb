# frozen_string_literal: true

module Insured
  class MembersSelectionController < ApplicationController

    def new
      @organizer = Organizers::MembersSelectionPrevaricationAdapter.call(params: params.symbolize_keys)

      if @organizer.success?
        @can_shop_both_markets = false
        set_bookmark_url
      else
        redirect_to new_insured_members_selections_path
      end
    end

    def fetch
      @organizer = Organizers::CoverageEligibilityForGivenEmployeeRole.call(params: params.symbolize_keys, market_kind: params["market_kind"])

      if @organizer.success?
        respond_to do |format|
          format.js
        end
      else
        redirect_to new_insured_members_selections_path
      end
    end

    def create
      @organizer = Organizers::CreateShoppingEnrollments.call(params: params.symbolize_keys, market_kind: params["market_kind"])

      if @organizer.failure?
        flash[:error] = error.message
        logger.error "#{error.message}\n#{error.backtrace.join("\n")}"
        employee_role_id = @organizer.employee_role.id if @organizer.employee_role
        consumer_role_id = @organizer.consumer_role.id if @organizer.consumer_role
        return redirect_to new_insured_members_selections_path(person_id: @person.id, employee_role_id: employee_role_id, change_plan: @change_plan, market_kind: @market_kind, consumer_role_id: consumer_role_id, enrollment_kind: @enrollment_kind)
      end

      enrollments_presistence = @organizer.shopping_enrollments.map(&:save)
      raise "You must select the primary applicant to enroll in the healthcare plan" unless enrollments_presistence.all?(true)
    end
  end
end