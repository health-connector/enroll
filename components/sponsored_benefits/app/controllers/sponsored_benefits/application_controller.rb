# frozen_string_literal: true

module SponsoredBenefits
  class ApplicationController < ActionController::Base
    before_action :set_broker_agency_profile_from_user

    rescue_from ActionController::InvalidAuthenticityToken, :with => :bad_token_due_to_session_expired

    private

    helper_method :active_tab

    def bad_token_due_to_session_expired
      flash[:warning] = "Session expired."
      respond_to do |format|
        format.html { redirect_to root_path}
        format.js   { render text: "window.location.assign('#{root_path}');"}
        format.json { render json: { :token_expired => root_url }, status: :unauthorized }
      end
    end

    def active_tab
      "employers-tab"
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def set_broker_agency_profile_from_user
      redirect_to main_app.root_path, :flash => { :error => "You are not authorized to view this page." } unless current_person.present? && (current_person.broker_role.present? || active_user.has_hbx_staff_role?)
      if current_person.present? && current_person.broker_role.present?
        @broker_agency_profile = BenefitSponsors::Organizations::Profile.find(current_person.broker_role.benefit_sponsors_broker_agency_profile_id)
        @broker_agency_profile ||= ::BrokerAgencyProfile.find(current_person.broker_role.broker_agency_profile_id) # Deprecate this
      elsif active_user.present? && active_user.has_hbx_staff_role? && params[:plan_design_organization_id].present?
        @broker_agency_profile = BenefitSponsors::Organizations::Profile.find(params[:plan_design_organization_id])
        @broker_agency_profile ||= ::BrokerAgencyProfile.find(params[:plan_design_organization_id]) # Deprecate this
      else
        org = fetch_plan_design_organization(params)
        return unless org.present?

        @broker_agency_profile = BenefitSponsors::Organizations::Profile.find(org.owner_profile_id)
        @broker_agency_profile ||= ::BrokerAgencyProfile.find(org.owner_profile_id) # Deprecate this
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def fetch_plan_design_organization(params)
      if params[:plan_design_proposal_id].present?
        SponsoredBenefits::Organizations::PlanDesignProposal.find(params[:plan_design_proposal_id]).plan_design_organization
      elsif params[:id].present? && !request.env['PATH_INFO'].include?('broker_agency_profile')
        case controller_name
        when "plan_design_proposals"
          SponsoredBenefits::Organizations::PlanDesignProposal.find(params[:id]).plan_design_organization
        when "plan_design_organizations"
          SponsoredBenefits::Organizations::PlanDesignOrganization.find(params[:id])
        end
      end
    end

    def current_person
      return unless current_user.present?

      current_user.person
    end

    def active_user
      current_user
    end
  end
end