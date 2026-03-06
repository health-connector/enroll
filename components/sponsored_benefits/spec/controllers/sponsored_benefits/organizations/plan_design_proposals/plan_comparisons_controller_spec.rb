# frozen_string_literal: true

require 'rails_helper'
require "#{SponsoredBenefits::Engine.root}/spec/shared_contexts/sponsored_benefits"

module SponsoredBenefits
  RSpec.describe Organizations::PlanDesignProposals::PlanComparisonsController, type: :controller, dbclean: :around_each do
    routes { SponsoredBenefits::Engine.routes }
    include_context "set up broker agency profile for BQT, by using configuration settings"

    let!(:person) do
      FactoryBot.create(:person, :with_broker_role).tap do |person|
        person.broker_role.update_attributes(broker_agency_profile_id: plan_design_organization.owner_profile_id)
      end
    end
    let!(:user) { FactoryBot.create(:user, person: person) }

    let(:plan1) { health_plan }
    let(:plan2) { health_plan }
    let(:plan_ids) { [plan1.id.to_s, plan2.id.to_s] }

    let(:qhp1) { double("Products::QhpCostShareVariance", plan: plan1) }
    let(:qhp2) { double("Products::QhpCostShareVariance", plan: plan2) }
    let(:qhps) { [qhp1, qhp2] }

    before do
      allow_any_instance_of(SponsoredBenefits::Organizations::PlanDesignOrganization).to receive(:is_renewing_employer?).and_return(false)
      allow_any_instance_of(SponsoredBenefits::Services::PlanCostService).to receive(:monthly_employer_contribution_amount).and_return(0.0)
      benefit_application
      sign_in user
      allow(controller).to receive(:qhps).and_return(qhps)
      allow(::Products::QhpCostShareVariance).to receive(:find_qhp_cost_share_variances).and_return(qhps)
    end

    describe "GET #export" do
      let(:params) { { plan_design_proposal_id: plan_design_proposal.id, plans: plan_ids } }

      before do
        allow_any_instance_of(Organizations::PlanDesignProposals::PlanComparisonsController).to receive(:render_to_string).and_return('')
        get :export, params: params, format: :pdf
      end

      it "returns a pdf response" do
        expect(response.content_type).to eq('application/pdf')
      end
    end

    describe "GET #csv" do
      let(:params) { { plan_design_proposal_id: plan_design_proposal.id, plans: plan_ids } }
      let(:csv_data) { "plan,cost\nPlan 1,100.00\n" }

      before do
        allow(::Products::Qhp).to receive(:csv_for).and_return(csv_data)
        allow(qhp1).to receive(:[]=).with(:total_employee_cost, anything)
        allow(qhp2).to receive(:[]=).with(:total_employee_cost, anything)
        get :csv, params: params, format: :csv
      end

      it "returns CSV data" do
        expect(response.content_type).to eq('text/csv')
      end

      it "assigns employer costs to QHP data" do
        expect(qhp1).to have_received(:[]=).with(:total_employee_cost, anything)
        expect(qhp2).to have_received(:[]=).with(:total_employee_cost, anything)
      end
    end

    describe "helper methods" do
      describe "#visit_types" do
        it "returns health visit types" do
          expect(controller.send(:visit_types)).to eq(::Products::Qhp::VISIT_TYPES)
        end
      end
    end

    describe "employer cost functionality" do
      it "has method to calculate employer costs" do
        expect(controller.private_methods).to include(:calculate_employer_costs)
      end

      it "has method to build temporary benefit groups" do
        expect(controller.private_methods).to include(:build_temp_benefit_group_for_plan)
      end
    end
  end
end
