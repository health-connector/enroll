# frozen_string_literal: true

module Insured
  class MembersSelectionController < ApplicationController
    before_action :set_family, only: [:new, :eligible_coverage_selection, :fetch, :create]

    def new
      @organizer = Organizers::MembersSelectionPrevaricationAdapter.call(params: params.to_unsafe_h.symbolize_keys.except(:controller, :action), event: params[:event])

      if @organizer.success?
        @can_shop_both_markets = false
        set_bookmark_url
      else
        flash[:error] = @organizer.message
        redirect_back fallback_location: main_app.root_path
      end
    end

    def eligible_coverage_selection
      @organizer = Organizers::EligibleCoverageSelectionForNew.call(params: params.to_unsafe_h.symbolize_keys)

      if @organizer.failure? # rubocop:disable Style/GuardClause
        flash[:error] = @organizer.message
        redirect_back fallback_location: main_app.root_path
      end

      @organizer.event = "shop_for_plans"
    end

    def fetch
      @organizer = Organizers::CoverageEligibilityForGivenEmployeeRole.call(params: params.to_unsafe_h.symbolize_keys, market_kind: params["market_kind"], event: params[:event])

      if @organizer.success?
        respond_to do |format|
          format.js
        end
      else
        redirect_to new_insured_members_selections_path
      end
    end

    def create
      @organizer = Organizers::CreateShoppingEnrollments.call(params: params.to_unsafe_h.symbolize_keys, market_kind: params["market_kind"], session_original_application_type: session[:original_application_type], current_user: current_user)
      if @organizer.failure?
        flash[:error] = @organizer.message
        logger.error "#{@organizer.message}\n"
        redirect_back fallback_location: main_app.root_path
        return
        #employee_role_id = @organizer.employee_role.id if @organizer.employee_role
        # TODO
        # redirect_to new_insured_members_selections_path(person_id: @person.id, employee_role_id: employee_role_id, change_plan: @change_plan, market_kind: @market_kind, enrollment_kind: @enrollment_kind)
      end

      sponsored_benefits = params[:shopping_members]&.keys || @organizer.employee_role&.benefit_package&.sponsored_benefits&.map(&:product_kind) || ["dental", "health"]
      if @organizer.enrollments_to_waive.sort == sponsored_benefits.map(&:to_s).sort
        redirect_to waiver_thankyou_insured_product_shoppings_path(@organizer[:plan_selection_json])
      elsif @organizer.commit == "Keep existing plan" && @organizer.previous_hbx_enrollment.present?
        # TODO
        redirect_to thankyou_insured_product_shoppings_path(cart: keep_existing_plan_cart)
      else
        redirect_to continuous_show_insured_product_shoppings_path(@organizer[:plan_selection_json])
      end
    end

    private

    def set_family
      @person = Person.find(params[:person_id]) if params[:person_id]
      @family = @person.primary_family
      authorize @family, :member_selection_coverage?
    end

    def keep_existing_plan_cart
      shopping_enrollment = @organizer.shopping_enrollments.first
      {shopping_enrollment.coverage_kind => {"id": shopping_enrollment.id, "product_id": @organizer.previous_hbx_enrollment.product_id}}
    end
  end
end