# frozen_string_literal: true

module Insured
  class MembersSelectionController < ApplicationController
    def new
      @organizer = Organizers::MembersSelectionPrevaricationAdapter.call(params: params.symbolize_keys.except(:controller, :action), event: params[:event])

      if @organizer.success?
        @can_shop_both_markets = false
        set_bookmark_url
      else
        flash[:error] = @organizer.message
        redirect_to(:back)
      end
    end

    def eligible_coverage_selection
      @organizer = Organizers::EligibleCoverageSelectionForNew.call(params: params.symbolize_keys)

      if @organizer.failure? # rubocop:disable Style/GuardClause
        flash[:error] = @organizer.message
        redirect_to(:back)
      end

      @organizer.event = "shop_for_plans"
    end

    def fetch
      @organizer = Organizers::CoverageEligibilityForGivenEmployeeRole.call(params: params.symbolize_keys, market_kind: params["market_kind"], event: params[:event])

      if @organizer.success?
        respond_to do |format|
          format.js
        end
      else
        redirect_to new_insured_members_selections_path
      end
    end

    def create
      @organizer = Organizers::CreateShoppingEnrollments.call(params: params.symbolize_keys, market_kind: params["market_kind"], session_original_application_type: session[:original_application_type], current_user: current_user)
      if @organizer.failure?
        flash[:error] = @organizer.message
        logger.error "#{@organizer.message}\n"
        redirect_to(:back)
        return
        #employee_role_id = @organizer.employee_role.id if @organizer.employee_role
        # TODO
        # redirect_to new_insured_members_selections_path(person_id: @person.id, employee_role_id: employee_role_id, change_plan: @change_plan, market_kind: @market_kind, enrollment_kind: @enrollment_kind)
      end

      if @organizer.commit == "Keep existing plan" && @organizer.previous_hbx_enrollment.present?
        # TODO
        redirect_to thankyou_insured_product_shoppings_path(keep_existing_plan_cart)
      else
        redirect_to continuous_show_insured_product_shoppings_path(@organizer[:plan_selection_json])
      end
    end

    private

    def keep_existing_plan_cart
      shopping_enrollment = @organizer.shopping_enrollments.first
      {shopping_enrollment.coverage_kind => {"id": shopping_enrollment.id, "product_id": @organizer.previous_hbx_enrollment.product_id}}
    end
  end
end