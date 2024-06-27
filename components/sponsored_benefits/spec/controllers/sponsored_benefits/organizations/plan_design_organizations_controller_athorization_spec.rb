# frozen_string_literal: true

require 'rails_helper'
require "#{SponsoredBenefits::Engine.root}/spec/shared_contexts/sponsored_benefits"

module SponsoredBenefits
  RSpec.describe Organizations::PlanDesignOrganizationsController, type: :controller, dbclean: :around_each  do
    include_context "set up broker agency profile for BQT, by using configuration settings"

    routes { SponsoredBenefits::Engine.routes }
    include Rails.application.routes.url_helpers

    context "when the logged-in user is not authorized to access" do
      let(:fake_user) { FactoryBot.create(:user, person: fake_person) }
      let(:fake_person) do
        FactoryBot.create(:person, :with_broker_role).tap do |person|
          person.broker_role.update_attributes(broker_agency_profile_id: broker_agency_profile.id.to_s)
        end
      end
      let(:valid_attributes) {
          {
            "legal_name"  =>  "Some Name",
            "dba"         =>  "",
            "entity_kind" =>  "",
            "sic_code"    =>  "0116"
          }
      }

      it "redirects to the root path and displays an error message" do
        sign_in(fake_user)

        get :edit, params: { id: prospect_plan_design_organization.to_param }
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("Access not allowed for edit?, (Pundit policy)")
      end

      it "redirects to the root path and displays an error message" do
        sign_in(fake_user)

        delete :destroy, params: {:id => prospect_plan_design_organization.to_param }
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("Access not allowed for destroy?, (Pundit policy)")
      end

      it "redirects to the root path and displays an error message" do
        sign_in(fake_user)

        patch :update, params: { organization: valid_attributes, id: prospect_plan_design_organization.id }
        expect(flash[:error]).to eq("Access not allowed for update?, (Pundit policy)")
      end

      it "redirects to the root path and displays an error message" do
        sign_in(fake_user)

        get :new, params: { plan_design_organization_id: prospect_plan_design_organization.id, broker_agency_id:  broker_agency_profile.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("Access not allowed for plan_design_org_new?, (Pundit policy)")
      end

      it "redirects to the root path and displays an error message" do
        sign_in(fake_user)

        post :create, params: { organization: valid_attributes, broker_agency_id: broker_agency_profile.id, format: 'js'}
        expect(flash[:error]).to eq("Access not allowed for plan_design_org_create?, (Pundit policy)")
      end
    end
  end
end
