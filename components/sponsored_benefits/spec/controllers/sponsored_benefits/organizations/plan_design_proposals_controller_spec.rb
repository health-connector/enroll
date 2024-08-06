# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

module DataTablesAdapter
end

module SponsoredBenefits
  RSpec.describe Organizations::PlanDesignProposalsController, type: :controller, dbclean: :around_each do
    routes { SponsoredBenefits::Engine.routes }

    let(:broker_double) { double(id: '12345') }
    let(:current_person) { double(:current_person) }
    let(:datatable) { double(:datatable) }
    let(:sponsor) { double(:sponsor, id: '5ac4cb58be0a6c3ef400009a', sic_code: '1111') }
    let(:active_user) { double(:active_user, person: current_person) }
    let!(:plan_design_organization) {
        create(:sponsored_benefits_plan_design_organization, sponsor_profile_id: sponsor.id, owner_profile_id: '5ac4cb58be0a6c3ef400009b', plan_design_proposals: [ plan_design_proposal ], sic_code: sponsor.sic_code )
    }

    let(:broker_agency_profile_id) { "5ac4cb58be0a6c3ef400009b" }
    let(:broker_agency_profile) do
      double(
        :sponsored_benefits_broker_agency_profile,
        id: broker_agency_profile_id, persisted: true, fein: "5555", hbx_id: "123312", legal_name: "ba-name",
        dba: "alternate", is_active: true, organization: plan_design_organization, office_locations: []
      )
    end

    let(:broker_role) { double(:broker_role, broker_agency_profile_id: broker_agency_profile.id) }

    let(:sponsorship) { build(:plan_design_benefit_sponsorship,
                        benefit_market: :aca_shop_cca,
                        initial_enrollment_period: initial_enrollment_period,
                        annual_enrollment_period_begin_month: beginning_of_next_month.month,
                        benefit_applications: [ benefit_application ]
                        ) }
    let(:benefit_application) { build(:plan_design_benefit_application, effective_period: initial_enrollment_period, open_enrollment_period: (open_enrollment_start_on..(open_enrollment_start_on+20.days))) }
    let(:cca_employer_profile) {
      employer = build(:shop_cca_employer_profile)
      employer.benefit_sponsorships = [sponsorship]
      employer
    }
    let(:plan_design_proposal) { build(:plan_design_proposal, profile: cca_employer_profile) }
    let(:open_enrollment_start_on) { (beginning_of_next_month - 15.days).prev_month }
    let(:beginning_of_next_month) { Date.today.next_month.beginning_of_month }
    let(:end_of_month) { Date.today.end_of_month }
    let(:initial_enrollment_period) { (beginning_of_next_month..(beginning_of_next_month + 1.year - 1.day)) }

    let(:valid_attributes) {
      {
        title: 'A Proposal Title',
        effective_date: beginning_of_next_month.strftime("%Y-%m-%d"),
        profile: {
          benefit_sponsorship: {
            initial_enrollment_period: initial_enrollment_period,
            annual_enrollment_period_begin_month_of_year: beginning_of_next_month.month,
            benefit_application: {
              effective_period: initial_enrollment_period,
              open_enrollment_period: (Date.today..end_of_month)
            }
          }
        }
      }
    }


    let(:invalid_attributes) {
      {
        title: 'A Proposal Title',
        effective_date: beginning_of_next_month.strftime("%Y-%m-%d"),
        profile: {
          benefit_sponsorship: {
            initial_enrollment_period: nil,
            annual_enrollment_period_begin_month_of_year: beginning_of_next_month.month,
            benefit_application: {
              effective_period: ((end_of_month + 1.year)..beginning_of_next_month),
              open_enrollment_period: (beginning_of_next_month.end_of_month..beginning_of_next_month)
            }
          }
        }
      }
    }

    # This should return the minimal set of values that should be in the session
    # in order to pass any filters (e.g. authentication) defined in
    # BenefitApplications::BenefitApplicationsController. Be sure to keep this updated too.
    let(:valid_session) { {} }
    let(:fake_user) { FactoryBot.create(:user, person: fake_person) }
    let(:fake_person) do
      FactoryBot.create(:person, :with_broker_role).tap do |person|
        person.broker_role.update_attributes(broker_agency_profile_id: broker_agency_profile.id.to_s)
      end
    end

    before do
      allow(plan_design_organization).to receive(:is_renewing_employer?).and_return false
      benefit_application
      allow(subject).to receive(:current_person).and_return(current_person)
      allow(subject).to receive(:active_user).and_return(active_user)
      allow(active_user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(current_person).to receive(:broker_role).and_return(broker_role)
      allow(broker_role).to receive(:broker_agency_profile_id).and_return(broker_agency_profile.id)
      allow(subject).to receive(:effective_datatable).and_return(datatable)
      allow(subject).to receive(:employee_datatable).and_return(datatable)
      allow(broker_role).to receive(:benefit_sponsors_broker_agency_profile_id).and_return(broker_agency_profile.id)
      allow(controller).to receive(:set_broker_agency_profile_from_user).and_return(broker_agency_profile)
      allow(BenefitSponsors::Organizations::Profile).to receive(:find).with(BSON::ObjectId.from_string(broker_agency_profile.id)).and_return(broker_agency_profile)
      allow(BenefitSponsors::Organizations::Profile).to receive(:find).with(BSON::ObjectId.from_string(sponsor.id)).and_return(sponsor)
      sign_in(active_user)
    end

    describe "GET #index" do
      context "when user has authorization" do
        it "returns a success response" do
          get :index, params: { plan_design_organization_id: plan_design_organization.id }

          expect(response).to be_successful
        end
      end
    end

    describe "GET #show" do
      context "when user has authorization" do
        it "returns a success response" do
          get :show, params: { id: plan_design_proposal.to_param }

          expect(response).to be_successful
        end
      end
    end

    describe "GET #new" do
      context "when user has authorization" do
        it "returns a success response" do
          get :new, params: { plan_design_organization_id: plan_design_organization.id }

          expect(response).to be_successful
        end
      end
    end

    describe "GET #edit" do
      context "when user has authorization" do
        it "returns a success response" do
          get :edit, params: { id: plan_design_proposal.to_param, plan_design_organization_id: plan_design_organization.id }

          expect(response).to be_successful
        end
      end
    end

    describe "POST #create" do
      context "with valid params" do
        it "creates a new PlanDesignProposal and renders the create template" do
          expect {
            post :create, params: { plan_design_organization_id: plan_design_organization.to_param, forms_plan_design_proposal: valid_attributes }, format: :js
          }.to change { plan_design_organization.reload.plan_design_proposals.count }.by(1)

          expect(response).to render_template('create')
        end
      end

      context "with invalid params" do
        it "returns a success response to display the 'new' template" do
          post :create, params: { plan_design_organization_id: plan_design_organization.to_param, forms_plan_design_proposal: invalid_attributes }, format: :js

          expect(response).to be_successful
        end
      end
    end


    describe "authorization failure" do
      context "when user does not have authorization for index action" do
        it "returns a failure response" do
          sign_in(fake_user)
          get :index, params: { plan_design_organization_id: plan_design_organization.id }

          expect(flash[:error]).to eq("Access not allowed for plan_design_proposal_index?, (Pundit policy)")
        end
      end

      context "when user does not have authorization for show action" do
        it "returns a failure response" do
          sign_in(fake_user)
          get :show, params: { id: plan_design_proposal.to_param }

          expect(flash[:error]).to eq("Access not allowed for plan_design_proposal_show?, (Pundit policy)")
        end
      end

      context "when user does not have authorization" do
        it "returns a failure response" do
          sign_in(fake_user)
          get :new, params: { plan_design_organization_id: plan_design_organization.id }

          expect(flash[:error]).to eq("Access not allowed for plan_design_proposal_new?, (Pundit policy)")
        end
      end

      context "when user does not have authorization" do
        it "returns a failure response" do
          sign_in(fake_user)
          get :edit, params: { id: plan_design_proposal.to_param, plan_design_organization_id: plan_design_organization.id }

          expect(flash[:error]).to eq("Access not allowed for plan_design_proposal_edit?, (Pundit policy)")
        end
      end

      context "when user does not have authorization" do
        it "returns a failure response" do
          sign_in(fake_user)
          post :create, params: { plan_design_organization_id: plan_design_organization.to_param, forms_plan_design_proposal: invalid_attributes }, format: :js

          expect(flash[:error]).to eq("Access not allowed for plan_design_proposal_create?, (Pundit policy)")
        end
      end

      context "when user does not have authorization" do
        it "returns a failure response" do
          sign_in(fake_user)
          delete :destroy, params: {:id => plan_design_proposal.to_param}

          expect(flash[:error]).to eq("Access not allowed for plan_design_proposal_destroy?, (Pundit policy)")
        end
      end

      context "when user does not have authorization" do
        it "returns a failure response" do
          sign_in(fake_user)
          post :publish, params: {plan_design_proposal_id: plan_design_proposal.to_param}

          expect(flash[:error]).to eq("Access not allowed for plan_design_proposal_publish?, (Pundit policy)")
        end
      end

      context "when user does not have authorization" do
        include_context 'setup benefit market with market catalogs and product packages'
        include_context 'setup initial benefit application'

        let(:plan_design_proposal) { build(:plan_design_proposal, profile: abc_profile) }

        it "returns a failure response" do
          sign_in(fake_user)
          get :claim, params: {employer_profile_id: abc_profile.id}

          expect(flash[:error]).to eq("Access not allowed for plan_design_proposal_claim?, (Pundit policy)")
        end
      end
    end

    # describe "PUT #update" do
    #   context "with valid params" do
    #     let(:new_attributes) {
    #       skip("Add a hash of attributes valid for your model")
    #     }

    #     it "updates the requested organizations_plan_design_proposal" do
    #       plan_design_proposal = Organizations::PlanDesignProposal.create! valid_attributes
    #       put :update, {:id => plan_design_proposal.to_param, :organizations_plan_design_proposal => new_attributes}, valid_session
    #       plan_design_proposal.reload
    #       skip("Add assertions for updated state")
    #     end

    #     it "redirects to the organizations_plan_design_proposal" do
    #       plan_design_proposal = Organizations::PlanDesignProposal.create! valid_attributes
    #       put :update, {:id => plan_design_proposal.to_param, :organizations_plan_design_proposal => valid_attributes}, valid_session
    #       expect(response).to redirect_to(plan_design_proposal)
    #     end
    #   end

    #   context "with invalid params" do
    #     it "returns a success response (i.e. to display the 'edit' template)" do
    #       plan_design_proposal = Organizations::PlanDesignProposal.create! valid_attributes
    #       put :update, {:id => plan_design_proposal.to_param, :organizations_plan_design_proposal => invalid_attributes}, valid_session
    #       expect(response).to be_success
    #     end
    #   end
    # end

    # describe "DELETE #destroy" do
    #   it "destroys the requested organizations_plan_design_proposal" do
    #     plan_design_proposal = Organizations::PlanDesignProposal.create! valid_attributes
    #     expect {
    #       delete :destroy, {:id => plan_design_proposal.to_param}, valid_session
    #     }.to change(Organizations::PlanDesignProposal, :count).by(-1)
    #   end

    #   it "redirects to the organizations_plan_design_proposals list" do
    #     plan_design_proposal = Organizations::PlanDesignProposal.create! valid_attributes
    #     delete :destroy, {:id => plan_design_proposal.to_param}, valid_session
    #     expect(response).to redirect_to(organizations_plan_design_proposals_url)
    #   end
    # end

  end
end
