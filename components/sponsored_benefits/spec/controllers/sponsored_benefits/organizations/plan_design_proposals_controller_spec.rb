require 'rails_helper'
module DataTablesAdapter
end

module SponsoredBenefits
  RSpec.describe Organizations::PlanDesignProposalsController, type: :controller, dbclean: :around_each do
    routes { SponsoredBenefits::Engine.routes }
    let(:broker_double) { double(id: '12345') }
    let(:current_person) { double(:current_person) }
    let(:datatable) { double(:datatable) }
    let(:sponsor) { double(:sponsor, id: '5ac4cb58be0a6c3ef400009a', sic_code: '1111') }
    let(:active_user) { double(:has_hbx_staff_role? => false) }

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

    before do
      allow(subject).to receive(:current_person).and_return(current_person)
      allow(subject).to receive(:active_user).and_return(active_user)
      allow(current_person).to receive(:broker_role).and_return(broker_role)
      allow(broker_role).to receive(:broker_agency_profile_id).and_return(broker_agency_profile.id)
      allow(subject).to receive(:effective_datatable).and_return(datatable)
      allow(subject).to receive(:employee_datatable).and_return(datatable)
      allow(broker_role).to receive(:benefit_sponsors_broker_agency_profile_id).and_return(broker_agency_profile.id)
      allow(controller).to receive(:set_broker_agency_profile_from_user).and_return(broker_agency_profile)
      allow(BenefitSponsors::Organizations::Profile).to receive(:find).with(BSON::ObjectId.from_string(broker_agency_profile.id)).and_return(broker_agency_profile)
      allow(BenefitSponsors::Organizations::Profile).to receive(:find).with(BSON::ObjectId.from_string(sponsor.id)).and_return(sponsor)
    end

    describe "GET #index" do
      it "returns a success response" do
        xhr :get, :index, { plan_design_organization_id: plan_design_organization.id }, valid_session
        expect(response).to be_success
      end
    end

    describe "GET #show" do
      it "returns a success response" do
        get :show, { id: plan_design_proposal.to_param }, valid_session
        expect(response).to be_success
      end
    end

    describe "GET #new" do
      it "returns a success response" do
        get :new, { plan_design_organization_id: plan_design_organization.id }, valid_session
        expect(response).to be_success
      end
    end

    describe "GET #edit" do
      it "returns a success response" do
        get :edit, { id: plan_design_proposal.to_param, plan_design_organization_id: plan_design_organization.id }, valid_session
        expect(response).to be_success
      end
    end

    describe "POST #create" do
      context "with valid params" do
        it "creates a new Organizations::PlanDesignProposal" do
          expect {
            xhr :post, :create, { plan_design_organization_id: plan_design_organization.to_param, forms_plan_design_proposal: valid_attributes }, valid_session
          }.to change { plan_design_organization.reload.plan_design_proposals.count }.by(1)
        end

        it "redirects to the created benefit_application" do
          xhr :post, :create, { plan_design_organization_id: plan_design_organization.to_param, forms_plan_design_proposal: valid_attributes }, valid_session
          expect(response).to render_template('create')
        end
      end

      context "with invalid params" do
        it "returns a success response (i.e. to display the 'new' template)" do
          xhr :post, :create, { plan_design_organization_id: plan_design_organization.to_param, forms_plan_design_proposal: invalid_attributes}, valid_session
          expect(response).to be_success
        end
      end
    end

    describe '#claim', dbclean: :after_each do
      let(:plan_design_organization) do
        FactoryBot.create :sponsored_benefits_plan_design_organization,
                          owner_profile_id: owner_profile.id,
                          sponsor_profile_id: sponsor_profile.id
      end

      let(:plan_design_proposal) do
        pdp =
          FactoryBot.create(
            :plan_design_proposal,
            :with_profile,
            plan_design_organization: plan_design_organization
          ).tap do |proposal|
            sponsorship = proposal.profile.benefit_sponsorships.first
            sponsorship.initial_enrollment_period = benefit_sponsorship_enrollment_period
            sponsorship.save
          end
        pdp.publish!
        pdp
      end

      let(:ofice_location) { proposal_profile.office_locations.where(is_primary: true).first }

      let(:proposal_profile) { plan_design_proposal.profile }

      let(:benefit_sponsorship_enrollment_period) do
        begin_on = SponsoredBenefits::BenefitApplications::BenefitApplication.calculate_start_on_dates[0]
        end_on = begin_on + 1.year - 1.day
        begin_on..end_on
      end

      let(:benefit_sponsorship) { proposal_profile.benefit_sponsorships.first }

      let(:benefit_application) do
        FactoryBot.create :plan_design_benefit_application,
                          :with_benefit_group,
                          benefit_sponsorship: benefit_sponsorship
      end

      let(:benefit_group) do
        benefit_application.benefit_groups.first.tap do |benefit_group|
          benefit_group.update_attributes(reference_plan_id: benefit_group.reference_plan_id, plan_option_kind: 'single_plan')
        end
      end

      let(:owner_profile) { broker_agency_profile }
      let(:broker_agency) { owner_profile.organization }
      let(:general_agency_profile) { ga_profile }

      let(:employer_profile) { sponsor_profile }
      let(:benefit_sponsor) { sponsor_profile.organization }

      [2016, 2017, 2018, 2019].each do |year|
        let!("health_plans_for_#{year}".to_sym) do
          FactoryBot.create_list(:plan, 77, :with_complex_premium_tables, active_year: year, coverage_kind: "health")
        end
      end

      let(:organization) { plan_design_organization.sponsor_profile.organization }

      let!(:current_effective_date) do
        (TimeKeeper.date_of_record + 2.months).beginning_of_month.prev_year
      end

      let!(:broker_agency_profile) do
        if Settings.aca.state_abbreviation == "DC" # toDo
          FactoryBot.create(:broker_agency_profile)
        else
          FactoryBot.create(
            :benefit_sponsors_organizations_general_organization,
            :with_site,
            :with_broker_agency_profile
          ).profiles.first
        end
      end

      let(:site)                { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :with_benefit_market_catalog_and_product_packages, :dc) }

      let(:benefit_market)      { site.benefit_markets.first }
      let(:benefit_market_catalog)  { benefit_market.benefit_market_catalogs.first }

      let!(:sponsor_profile) do
        if Settings.aca.state_abbreviation == "DC" # toDo
          FactoryBot.create(
            :benefit_sponsors_organizations_general_organization,
            :with_aca_shop_dc_employer_profile,
            site: site
          ).profiles.first
        else
          FactoryBot.create(
            :benefit_sponsors_organizations_general_organization,
            :with_site,
            :with_aca_shop_cca_employer_profile
          ).profiles.first
        end
      end

      let!(:sponsor_profile_benefit_sponsorship) do
        bs = sponsor_profile.add_benefit_sponsorship
        bs.save
        bs
      end

      let!(:relationship_benefit) { benefit_group.relationship_benefits.first }

      before :each do
        get :claim, params: { employer_profile_id: sponsor_profile_benefit_sponsorship.profile.id, claim_code: plan_design_proposal.claim_code}
      end

      it 'should claim the code successfully' do
        sponsor_profile_benefit_sponsorship.organization.reload
        expect(sponsor_profile_benefit_sponsorship.reload.benefit_applications.count).to eq 1
      end

      # it 'should show success flash message' do
      #   expect(flash[:notice]).to eq 'Code claimed with success. Your Plan Year has been created.'
      # end
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
