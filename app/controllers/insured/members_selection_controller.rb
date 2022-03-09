# frozen_string_literal: true

module Insured
  class MembersSelectionController < ApplicationController

  # {"change_plan"=>"change_by_qle", "change_plan_date"=>"03/01/2022", "person_id"=>"60abddc907f0114a15b15227", "qle_id"=>"5b758a3307f0114bc18ecb1d", "sep_id"=>"6220f850d44d053fe620fbc3", "controller"=>"insured/members_selection", "action"=>"new"}

    def new
      initialize_variables_for_new
      set_bookmark_url
    end

    def create
    #wip
    end

    private

    def initialize_variables_for_new
      organizer = Organizers::MembersSelectionPrevaricationAdapter.call(params: params.symbolize_keys)

      # TODO: research for better approach
      if organizer.success?
        @person = organizer.person
        @family = organizer.primary_family
        # @coverage_household = organizer.coverage_household
        @family_members = organizer.family_members
        @hbx_enrollment = organizer.previous_hbx_enrollment
        @change_plan = organizer.change_plan
        @coverage_kind = organizer.coverage_kind
        @enrollment_kind = organizer.enrollment_kind
        @shop_for_plans = organizer.shop_for_plans
        @optional_effective_on = organizer.optional_effective_on
        @employee_role = organizer.employee_role
        @resident_role = organizer.resident_role
        @consumer_role = organizer.consumer_role
        @role = organizer.role


        @disable_market_kind = organizer.disabled_market_kind
        @mc_market_kind = organizer.mc_market_kind
        @mc_coverage_kind = organizer.mc_coverage_kind

        @market_kind = organizer.market_kind
        @benefit = organizer.benefit
        @qle = organizer.qle
        @benefit_group = organizer.benefit_group
        @shop_under_current = organizer.shop_under_current
        @shop_under_future = organizer.shop_under_future

        @new_effective_on = organizer.new_effective_on
        @coverage_family_members_for_cobra = organizer.coverage_family_members_for_cobra

        @waivable = organizer.waivable
        @can_shop_shop = @person.present? && @person.has_employer_benefits?
        @can_shop_individual = false
        @can_shop_resident = false
        @can_shop_both_markets = false
      end
    end
  end
end