# frozen_string_literal: true

module Insured
  class MembersSelectionController < ApplicationController

  # {"change_plan"=>"change_by_qle", "change_plan_date"=>"03/01/2022", "person_id"=>"60abddc907f0114a15b15227", "qle_id"=>"5b758a3307f0114bc18ecb1d", "sep_id"=>"6220f850d44d053fe620fbc3", "controller"=>"insured/members_selection", "action"=>"new"}
    before_action :initialize_common_vars, only: [:new, :create]

    def new
      set_bookmark_url
    #wip
    end

    def create
    #wip
    end

    private

    def initialize_common_vars
      organizer = Organizers::MembersSelectionPrevaricationAdapter.call(params: params.symbolize_keys)
      @person = organizer.person
      @family = organizer.family
      @coverage_household = organizer.coverage_household
      @hbx_enrollment = organizer.previous_hbx_enrollment
      @change_plan = organizer.change_plan
      @coverage_kind = organizer.coverage_kind
      @enrollment_kind = organizer.enrollment_kind
      @shop_for_plans = organizer.shop_for_plans
      @optional_effective_on = organizer.optional_effective_on
    end

  end
end