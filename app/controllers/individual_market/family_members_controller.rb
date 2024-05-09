# frozen_string_literal: true

module IndividualMarket
  class FamilyMembersController < ApplicationController
    include VlpDoc
    include ApplicationHelper

    before_action :set_current_person, :set_family

    # rubocop:disable Metrics/AbcSize
    def resident_index
      set_bookmark_url
      @resident_role = @person.resident_role
      @change_plan = params[:change_plan].present? ? 'change_by_qle' : ''
      @change_plan_date = params[:qle_date].present? ? params[:qle_date] : ''

      if params[:qle_id].present?
        qle = QualifyingLifeEventKind.find(params[:qle_id])
        special_enrollment_period = @family.special_enrollment_periods.new(effective_on_kind: params[:effective_on_kind])
        @effective_on_date = special_enrollment_period.selected_effective_on = Date.strptime(params[:effective_on_date], "%m/%d/%Y") if params[:effective_on_date].present?
        special_enrollment_period.qualifying_life_event_kind = qle
        special_enrollment_period.qle_on = Date.strptime(params[:qle_date], "%m/%d/%Y")
        special_enrollment_period.qle_answer = params[:qle_reason_choice] if params[:qle_reason_choice].present?
        special_enrollment_period.save
        @market_kind = "coverall"
      end

      if request.referer.present?
        @prev_url_include_intractive_identity = request.referer.include?("interactive_identity_verifications")
        @prev_url_include_consumer_role_id = request.referer.include?("consumer_role_id")
      else
        @prev_url_include_intractive_identity = false
        @prev_url_include_consumer_role_id = false
      end
    end
    # rubocop:enable Metrics/AbcSize

    def new_resident_dependent
      @dependent = Forms::FamilyMember.new(:family_id => params.require(:family_id))
      respond_to do |format|
        format.html
        format.js
      end
    end

    def edit_resident_dependent
      @dependent = Forms::FamilyMember.find(params.require(:id))
      respond_to do |format|
        format.html
        format.js
      end
    end

    def show_resident_dependent
      @dependent = Forms::FamilyMember.find(params.require(:id))
      respond_to do |format|
        format.html
        format.js
      end
    end

    private

    def set_family
      @family = @person.try(:primary_family)
    end
  end
end
