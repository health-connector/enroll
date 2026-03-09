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
      allow(EnrollRegistry).to receive(:feature_enabled?).and_call_original
      allow(EnrollRegistry).to receive(:feature_enabled?).with(:plan_comparison_tool).and_return(true)
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

      it "has method to fetch benefit group for calculation" do
        expect(controller.private_methods).to include(:fetch_benefit_group_for_calculation)
      end

      it "has method to extract benefit group params" do
        expect(controller.private_methods).to include(:benefit_group_params)
      end
    end

    describe "#fetch_benefit_group_for_calculation" do
      context "when benefit group already exists" do
        it "returns the existing benefit group" do
          allow(controller).to receive(:plan_design_proposal).and_return(plan_design_proposal)
          result = controller.send(:fetch_benefit_group_for_calculation)
          expect(result).to eq(benefit_group)
        end
      end

      context "when benefit group does not exist but params are provided" do
        let(:benefit_group_data) do
          {
            reference_plan_id: plan1.id.to_s,
            plan_option_kind: "sole_source",
            relationship_benefits_attributes: [
              { relationship: "employee", premium_pct: "50", offered: "true" }
            ],
            composite_tier_contributions_attributes: [
              { composite_rating_tier: "employee_only", employer_contribution_percent: "56", offered: "true" }
            ]
          }
        end

        let(:params_with_benefit_group) do
          {
            plan_design_proposal_id: plan_design_proposal.id,
            plans: plan_ids,
            elected_plan_kind: "sole_source",
            reference_plan_id: plan1.id.to_s,
            forms_plan_design_proposal: {
              profile: {
                benefit_sponsorship: {
                  benefit_application: {
                    benefit_group: benefit_group_data
                  }
                }
              }
            }
          }
        end

        before do
          # Remove existing benefit group to simulate new quote scenario
          benefit_application.benefit_groups.delete_all
          allow_any_instance_of(SponsoredBenefits::BenefitApplications::BenefitGroup).to receive(:build_estimated_composite_rates)
          allow_any_instance_of(SponsoredBenefits::BenefitApplications::BenefitGroup).to receive(:set_bounding_cost_plans)
          allow(controller).to receive(:plan_design_proposal).and_return(plan_design_proposal)
          allow(controller).to receive(:params).and_return(ActionController::Parameters.new(params_with_benefit_group))
        end

        it "builds a temporary benefit group from params" do
          result = controller.send(:fetch_benefit_group_for_calculation)
          expect(result).to be_present
          expect(result.persisted?).to be_falsey
        end

        it "sets plan_option_kind from params" do
          result = controller.send(:fetch_benefit_group_for_calculation)
          expect(result.plan_option_kind).to eq("sole_source")
        end

        it "sets reference_plan_id from params" do
          result = controller.send(:fetch_benefit_group_for_calculation)
          expect(result.reference_plan_id).to eq(plan1.id)
        end
      end

      context "when benefit group does not exist and no params provided" do
        before do
          benefit_application.benefit_groups.delete_all
          allow(controller).to receive(:plan_design_proposal).and_return(plan_design_proposal)
        end

        it "returns nil" do
          result = controller.send(:fetch_benefit_group_for_calculation)
          expect(result).to be_nil
        end
      end
    end

    describe "#build_temp_benefit_group_for_plan" do
      it "creates a new benefit group instance with the specified plan" do
        result = controller.send(:build_temp_benefit_group_for_plan, benefit_group, plan2)
        expect(result).to be_a(SponsoredBenefits::BenefitApplications::BenefitGroup)
        expect(result.reference_plan_id).to eq(plan2.id)
      end

      it "uses the same class as the active benefit group" do
        result = controller.send(:build_temp_benefit_group_for_plan, benefit_group, plan2)
        expect(result.class).to eq(benefit_group.class)
      end

      it "copies relationship benefits from active benefit group" do
        result = controller.send(:build_temp_benefit_group_for_plan, benefit_group, plan2)
        expect(result.relationship_benefits.count).to eq(benefit_group.relationship_benefits.count)
      end

      it "does not persist the temporary benefit group" do
        result = controller.send(:build_temp_benefit_group_for_plan, benefit_group, plan2)
        expect(result.persisted?).to be_falsey
      end

      context "when benefit group is sole_source" do
        let(:ctc_double) { double(composite_rating_tier: "employee_only", employer_contribution_percent: 56.0, offered: true) }

        before do
          allow(benefit_group).to receive(:sole_source?).and_return(true)
          allow(benefit_group).to receive(:composite_tier_contributions).and_return([ctc_double])
        end

        it "copies composite tier contributions" do
          allow_any_instance_of(SponsoredBenefits::BenefitApplications::BenefitGroup).to receive(:build_estimated_composite_rates)
          result = controller.send(:build_temp_benefit_group_for_plan, benefit_group, plan2)
          # Verify that the result has composite_tier_contributions built
          # (Even if the builds aren't persisted, they should be present in the association)
          expect(result.composite_tier_contributions).not_to be_empty
        end

        it "builds estimated composite rates" do
          expect_any_instance_of(SponsoredBenefits::BenefitApplications::BenefitGroup).to receive(:build_estimated_composite_rates)
          controller.send(:build_temp_benefit_group_for_plan, benefit_group, plan2)
        end
      end
    end

    describe "#calculate_employer_costs" do
      let(:service) { double("PlanCostService", monthly_employer_contribution_amount: 150.00) }

      before do
        allow(SponsoredBenefits::Services::PlanCostService).to receive(:new).and_return(service)
        allow(controller).to receive(:qhps).and_return(qhps)
        allow(controller).to receive(:plan_design_proposal).and_return(plan_design_proposal)
      end

      it "returns a hash of plan IDs to employer costs" do
        result = controller.send(:calculate_employer_costs)
        expect(result).to be_a(Hash)
        expect(result.keys).to include(plan1.id, plan2.id)
      end

      it "calculates costs for each plan" do
        result = controller.send(:calculate_employer_costs)
        expect(result[plan1.id]).to eq(150.00)
        expect(result[plan2.id]).to eq(150.00)
      end

      it "handles errors gracefully" do
        allow(service).to receive(:monthly_employer_contribution_amount).and_raise(StandardError.new("Test error"))
        result = controller.send(:calculate_employer_costs)
        expect(result[plan1.id]).to eq(0.00)
        expect(result[plan2.id]).to eq(0.00)
      end

      context "when no benefit group exists" do
        before do
          benefit_application.benefit_groups.delete_all
        end

        it "returns an empty hash" do
          result = controller.send(:calculate_employer_costs)
          expect(result).to eq({})
        end
      end
    end
  end
end
