# frozen_string_literal: true

require 'rails_helper'
require "#{SponsoredBenefits::Engine.root}/spec/shared_contexts/sponsored_benefits"

module SponsoredBenefits # rubocop:disable Metrics/ModuleLength
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
      allow(EnrollRegistry).to receive(:feature_enabled?).with(:employer_broker_ui_enhancements).and_return(true)
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
      let(:csv_data) { "plan,cost\nPlan 1,100.00\n" }

      before do
        allow(::Products::Qhp).to receive(:csv_for).and_return(csv_data)
        allow(qhp1).to receive(:[]=).with(:total_employee_cost, anything)
        allow(qhp2).to receive(:[]=).with(:total_employee_cost, anything)
      end

      context "without employer_costs parameter" do
        let(:params) { { plan_design_proposal_id: plan_design_proposal.id, plans: plan_ids } }

        before do
          allow(controller).to receive(:calculate_employer_costs).and_return({})
          get :csv, params: params, format: :csv
        end

        it "returns CSV data" do
          expect(response.content_type).to eq('text/csv')
        end

        it "assigns employer costs to QHP data" do
          expect(qhp1).to have_received(:[]=).with(:total_employee_cost, anything)
          expect(qhp2).to have_received(:[]=).with(:total_employee_cost, anything)
        end

        it "calls calculate_employer_costs" do
          expect(controller).to have_received(:calculate_employer_costs)
        end
      end

      context "with employer_costs parameter from frontend" do
        let(:employer_costs_param) { "#{plan1.id}:150.50,#{plan2.id}:200.75" }
        let(:params) do
          {
            plan_design_proposal_id: plan_design_proposal.id,
            plans: plan_ids,
            employer_costs: employer_costs_param
          }
        end

        before do
          get :csv, params: params, format: :csv
        end

        it "returns CSV data" do
          expect(response.content_type).to eq('text/csv')
        end

        it "assigns employer costs from params to QHP data" do
          expect(qhp1).to have_received(:[]=).with(:total_employee_cost, 150.50)
          expect(qhp2).to have_received(:[]=).with(:total_employee_cost, 200.75)
        end

        it "does not recalculate employer costs" do
          expect(controller).not_to have_received(:calculate_employer_costs) if controller.respond_to?(:calculate_employer_costs)
        end
      end

      context "with invalid employer_costs parameter" do
        let(:params) do
          {
            plan_design_proposal_id: plan_design_proposal.id,
            plans: plan_ids,
            employer_costs: "invalid_format"
          }
        end

        before do
          allow(Rails.logger).to receive(:error)
          allow(controller).to receive(:calculate_employer_costs).and_return({})
          get :csv, params: params, format: :csv
        end

        it "handles error gracefully" do
          expect(response.content_type).to eq('text/csv')
        end

        it "assigns default costs on parse error" do
          expect(qhp1).to have_received(:[]=).with(:total_employee_cost, 0.0)
          expect(qhp2).to have_received(:[]=).with(:total_employee_cost, 0.0)
        end
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

      it "has method to build fresh benefit group for calculation" do
        expect(controller.private_methods).to include(:build_fresh_benefit_group_for_calculation)
      end

      it "has method to build temporary benefit groups" do
        expect(controller.private_methods).to include(:build_temp_benefit_group_for_plan)
      end

      it "has method to route cost calculation per plan kind" do
        expect(controller.private_methods).to include(:cost_for_plan)
      end

      it "has method to calculate health costs" do
        expect(controller.private_methods).to include(:calculate_health_cost)
      end

      it "has method to calculate dental costs" do
        expect(controller.private_methods).to include(:calculate_dental_cost_for_all_employees)
      end

      it "has method to extract benefit group params" do
        expect(controller.private_methods).to include(:benefit_group_params)
      end

      it "has method to populate relationship benefits from dental attrs" do
        expect(controller.private_methods).to include(:populate_relationship_benefits_from_dental_attrs)
      end
    end

    describe "#build_fresh_benefit_group_for_calculation" do
      before do
        allow(controller).to receive(:plan_design_proposal).and_return(plan_design_proposal)
        allow_any_instance_of(SponsoredBenefits::BenefitApplications::BenefitGroup).to receive(:set_bounding_cost_plans)
        allow_any_instance_of(SponsoredBenefits::BenefitApplications::BenefitGroup).to receive(:build_estimated_composite_rates)
      end

      context "when benefit application is nil" do
        it "returns nil" do
          result = controller.send(:build_fresh_benefit_group_for_calculation, nil)
          expect(result).to be_nil
        end
      end

      context "when benefit application has no benefit groups" do
        before { benefit_application.benefit_groups.delete_all }

        it "returns nil" do
          result = controller.send(:build_fresh_benefit_group_for_calculation, benefit_application)
          expect(result).to be_nil
        end
      end

      context "without params" do
        it "returns the existing benefit group" do
          result = controller.send(:build_fresh_benefit_group_for_calculation, benefit_application)
          expect(result).to eq(benefit_group)
        end
      end

      context "with health benefit group params" do
        let(:benefit_group_data) do
          {
            reference_plan_id: plan1.id.to_s,
            plan_option_kind: "single_plan",
            relationship_benefits_attributes: {
              "0" => { relationship: "employee", premium_pct: "70", offered: "true" }
            }
          }
        end

        let(:params_with_benefit_group) do
          {
            plan_design_proposal_id: plan_design_proposal.id,
            plans: plan_ids,
            kind: "health",
            elected_plan_kind: "single_plan",
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
          allow(controller).to receive(:params).and_return(ActionController::Parameters.new(params_with_benefit_group))
        end

        it "builds a fresh in-memory benefit group" do
          result = controller.send(:build_fresh_benefit_group_for_calculation, benefit_application)
          expect(result).to be_present
          expect(result.persisted?).to be_falsey
        end

        it "sets plan_option_kind from params" do
          result = controller.send(:build_fresh_benefit_group_for_calculation, benefit_application)
          expect(result.plan_option_kind).to eq("single_plan")
        end

        it "sets reference_plan_id from params" do
          result = controller.send(:build_fresh_benefit_group_for_calculation, benefit_application)
          expect(result.reference_plan_id).to eq(plan1.id)
        end
      end

      context "with dental benefit group params" do
        let(:dental_plan) { dental_plan_with_sbc_document rescue FactoryBot.create(:plan, :with_dental_coverage) }

        let(:benefit_group_data) do
          {
            plan_option_kind: "single_plan",
            dental_relationship_benefits_attributes: {
              "0" => { relationship: "employee", premium_pct: "60", offered: "true" },
              "1" => { relationship: "spouse", premium_pct: "50", offered: "true" }
            }
          }
        end

        let(:params_with_dental) do
          {
            plan_design_proposal_id: plan_design_proposal.id,
            plans: plan_ids,
            kind: "dental",
            elected_plan_kind: "single_plan",
            dental_reference_plan_id: plan1.id.to_s,
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
          allow(controller).to receive(:params).and_return(ActionController::Parameters.new(params_with_dental))
        end

        it "builds a fresh in-memory benefit group for dental" do
          result = controller.send(:build_fresh_benefit_group_for_calculation, benefit_application)
          expect(result).to be_present
          expect(result.persisted?).to be_falsey
        end

        it "populates relationship_benefits from dental_relationship_benefits_attributes" do
          result = controller.send(:build_fresh_benefit_group_for_calculation, benefit_application)
          expect(result.relationship_benefits.map(&:relationship)).to include("employee", "spouse")
        end
      end

      context "with sole_source health params" do
        let(:benefit_group_data) do
          {
            plan_option_kind: "sole_source",
            composite_tier_contributions_attributes: {
              "0" => { composite_rating_tier: "employee_only", employer_contribution_percent: "67", offered: "true" },
              "1" => { composite_rating_tier: "family", employer_contribution_percent: "62", offered: "true" }
            }
          }
        end

        let(:params_with_sole_source) do
          {
            plan_design_proposal_id: plan_design_proposal.id,
            plans: plan_ids,
            kind: "health",
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
          allow(controller).to receive(:params).and_return(ActionController::Parameters.new(params_with_sole_source))
        end

        it "calls build_estimated_composite_rates for sole_source plans" do
          expect_any_instance_of(SponsoredBenefits::BenefitApplications::BenefitGroup).to receive(:build_estimated_composite_rates)
          controller.send(:build_fresh_benefit_group_for_calculation, benefit_application)
        end
      end
    end

    describe "#cost_for_plan" do
      let(:plan_double) { double("Plan", dental?: false) }
      let(:dental_plan_double) { double("Plan", dental?: true) }

      before do
        allow(controller).to receive(:calculate_health_cost).and_return(200.00)
        allow(controller).to receive(:calculate_dental_cost_for_all_employees).and_return(150.00)
      end

      it "routes health plans to calculate_health_cost" do
        result = controller.send(:cost_for_plan, benefit_group, plan_double)
        expect(controller).to have_received(:calculate_health_cost).with(benefit_group, plan_double)
        expect(result).to eq(200.00)
      end

      it "routes dental plans to calculate_dental_cost_for_all_employees" do
        result = controller.send(:cost_for_plan, benefit_group, dental_plan_double)
        expect(controller).to have_received(:calculate_dental_cost_for_all_employees).with(benefit_group, dental_plan_double)
        expect(result).to eq(150.00)
      end
    end

    describe "#calculate_health_cost" do
      let(:service) { double("PlanCostService", monthly_employer_contribution_amount: 175.00) }
      let(:temp_bg) { double("BenefitGroup") }

      before do
        allow(controller).to receive(:build_temp_benefit_group_for_plan).and_return(temp_bg)
        allow(SponsoredBenefits::Services::PlanCostService).to receive(:new).with(benefit_group: temp_bg).and_return(service)
      end

      it "uses PlanCostService to calculate health costs" do
        result = controller.send(:calculate_health_cost, benefit_group, plan1)
        expect(result).to eq(175.00)
      end

      it "returns 0.00 when service returns nil" do
        allow(service).to receive(:monthly_employer_contribution_amount).and_return(nil)
        result = controller.send(:calculate_health_cost, benefit_group, plan1)
        expect(result).to eq(0.00)
      end
    end

    describe "#calculate_dental_cost_for_all_employees" do
      let(:dental_plan) { FactoryBot.create(:plan, :with_dental_coverage) }
      let(:service) { double("PlanCostService", monthly_employer_contribution_amount: 90.00) }
      let(:temp_bg) { double("BenefitGroup") }

      before do
        allow(controller).to receive(:build_temp_benefit_group_for_plan).and_return(temp_bg)
        allow(SponsoredBenefits::Services::PlanCostService).to receive(:new).with(benefit_group: temp_bg).and_return(service)
      end

      it "uses PlanCostService to calculate dental costs" do
        result = controller.send(:calculate_dental_cost_for_all_employees, benefit_group, dental_plan)
        expect(result).to eq(90.00)
      end

      it "returns 0.00 when service returns nil" do
        allow(service).to receive(:monthly_employer_contribution_amount).and_return(nil)
        result = controller.send(:calculate_dental_cost_for_all_employees, benefit_group, dental_plan)
        expect(result).to eq(0.00)
      end

      it "returns 0.00 and logs error on exception" do
        allow(service).to receive(:monthly_employer_contribution_amount).and_raise(StandardError.new("Dental error"))
        allow(Rails.logger).to receive(:error)
        result = controller.send(:calculate_dental_cost_for_all_employees, benefit_group, dental_plan)
        expect(result).to eq(0.00)
        expect(Rails.logger).to have_received(:error).with(/Dental error/)
      end
    end

    describe "#populate_relationship_benefits_from_dental_attrs" do
      let(:dental_params) do
        {
          plan_design_proposal_id: plan_design_proposal.id,
          kind: "dental",
          forms_plan_design_proposal: {
            profile: {
              benefit_sponsorship: {
                benefit_application: {
                  benefit_group: {
                    plan_option_kind: "single_plan",
                    kind: "dental",
                    dental_relationship_benefits_attributes: {
                      "0" => { relationship: "employee", premium_pct: "70", offered: "true" },
                      "1" => { relationship: "spouse", premium_pct: "50", offered: "true" },
                      "2" => { relationship: "child_under_26", premium_pct: "50", offered: "false" }
                    }
                  }
                }
              }
            }
          }
        }
      end

      before do
        allow(controller).to receive(:params).and_return(ActionController::Parameters.new(dental_params))
      end

      it "populates relationship_benefits from dental_relationship_benefits_attributes" do
        controller.send(:populate_relationship_benefits_from_dental_attrs, benefit_group)
        relationships = benefit_group.relationship_benefits.map(&:relationship)
        expect(relationships).to include("employee", "spouse", "child_under_26")
      end

      it "sets offered correctly" do
        controller.send(:populate_relationship_benefits_from_dental_attrs, benefit_group)
        employee_rb = benefit_group.relationship_benefits.detect { |rb| rb.relationship == "employee" }
        child_rb = benefit_group.relationship_benefits.detect { |rb| rb.relationship == "child_under_26" }
        expect(employee_rb.offered).to be true
        expect(child_rb.offered).to be false
      end

      it "does not populate for health coverage_kind" do
        allow(controller).to receive(:params).and_return(ActionController::Parameters.new(dental_params.merge(kind: "health")))
        original_count = benefit_group.relationship_benefits.size
        controller.send(:populate_relationship_benefits_from_dental_attrs, benefit_group)
        expect(benefit_group.relationship_benefits.size).to eq(original_count)
      end
    end

    describe "#coverage_kind" do
      it "returns 'Health' when kind param is 'health'" do
        allow(controller).to receive(:params).and_return(ActionController::Parameters.new(kind: "health"))
        expect(controller.send(:coverage_kind)).to eq("Health")
      end

      it "returns 'Dental' when kind param is 'dental'" do
        allow(controller).to receive(:params).and_return(ActionController::Parameters.new(kind: "dental"))
        expect(controller.send(:coverage_kind)).to eq("Dental")
      end

      it "defaults to 'Health' when kind param is absent" do
        allow(controller).to receive(:params).and_return(ActionController::Parameters.new({}))
        expect(controller.send(:coverage_kind)).to eq("Health")
      end
    end

    describe "#build_temp_benefit_group_for_plan" do
      before do
        allow_any_instance_of(SponsoredBenefits::BenefitApplications::BenefitGroup).to receive(:set_bounding_cost_plans)
      end

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
        expect(result.relationship_benefits.size).to eq(benefit_group.relationship_benefits.size)
      end

      it "does not persist the temporary benefit group" do
        result = controller.send(:build_temp_benefit_group_for_plan, benefit_group, plan2)
        expect(result.persisted?).to be_falsey
      end

      it "calls set_bounding_cost_plans for health plans" do
        expect_any_instance_of(SponsoredBenefits::BenefitApplications::BenefitGroup).to receive(:set_bounding_cost_plans)
        controller.send(:build_temp_benefit_group_for_plan, benefit_group, plan2)
      end

      context "with a dental plan" do
        let(:dental_plan) { FactoryBot.create(:plan, :with_dental_coverage) }

        before { allow(dental_plan).to receive(:dental?).and_return(true) }

        it "sets dental_reference_plan_id instead of reference_plan_id" do
          result = controller.send(:build_temp_benefit_group_for_plan, benefit_group, dental_plan)
          expect(result.dental_reference_plan_id).to eq(dental_plan.id)
        end

        it "does not call set_bounding_cost_plans for dental plans" do
          expect_any_instance_of(SponsoredBenefits::BenefitApplications::BenefitGroup).not_to receive(:set_bounding_cost_plans)
          controller.send(:build_temp_benefit_group_for_plan, benefit_group, dental_plan)
        end
      end

      context "when benefit group is sole_source" do
        let(:ctc_double) { double(composite_rating_tier: "employee_only", employer_contribution_percent: 56.0, offered: true) }

        before do
          allow(benefit_group).to receive(:sole_source?).and_return(true)
          allow(benefit_group).to receive(:composite_tier_contributions).and_return([ctc_double])
        end

        it "copies composite tier contributions" do
          allow_any_instance_of(SponsoredBenefits::BenefitApplications::BenefitGroup).to receive(:estimate_composite_rates)
          result = controller.send(:build_temp_benefit_group_for_plan, benefit_group, plan2)
          expect(result.composite_tier_contributions).not_to be_empty
        end

        it "estimates composite rates" do
          expect_any_instance_of(SponsoredBenefits::BenefitApplications::BenefitGroup).to receive(:estimate_composite_rates)
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
        allow(qhp1.plan).to receive(:dental?).and_return(false)
        allow(qhp2.plan).to receive(:dental?).and_return(false)
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

      it "creates a fresh benefit group for each plan to avoid state pollution" do
        expect(controller).to receive(:build_fresh_benefit_group_for_calculation).exactly(qhps.size).times.and_call_original
        controller.send(:calculate_employer_costs)
      end

      it "handles errors gracefully per plan" do
        call_count = 0
        allow(controller).to receive(:cost_for_plan) do
          call_count += 1
          raise StandardError.new("Test error") if call_count == 1
          150.00
        end
        result = controller.send(:calculate_employer_costs)
        expect(result[plan1.id]).to eq(0.00)
        expect(result[plan2.id]).to eq(150.00)
      end

      context "when no benefit application exists" do
        before do
          allow(plan_design_proposal.profile.benefit_sponsorships.first).to receive(:benefit_applications).and_return([])
        end

        it "returns an empty hash" do
          result = controller.send(:calculate_employer_costs)
          expect(result).to eq({})
        end
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

      context "with dental plans" do
        let(:dental_plan1) { FactoryBot.create(:plan, :with_dental_coverage) }
        let(:dental_qhp1) { double("Products::QhpCostShareVariance", plan: dental_plan1) }

        before do
          allow(dental_plan1).to receive(:dental?).and_return(true)
          allow(controller).to receive(:qhps).and_return([dental_qhp1])
          allow(controller).to receive(:calculate_dental_cost_for_all_employees).and_return(80.00)
        end

        it "routes dental plans through calculate_dental_cost_for_all_employees" do
          result = controller.send(:calculate_employer_costs)
          expect(result[dental_plan1.id]).to eq(80.00)
        end
      end
    end

    describe "#parse_employer_costs_from_params" do
      let(:plan_id_1) { BSON::ObjectId.new }
      let(:plan_id_2) { BSON::ObjectId.new }
      let(:employer_costs_string) { "#{plan_id_1}:150.50,#{plan_id_2}:200.75" }

      before do
        allow(controller).to receive(:params).and_return(ActionController::Parameters.new(employer_costs: employer_costs_string))
      end

      it "parses employer costs from params string" do
        result = controller.send(:parse_employer_costs_from_params)
        expect(result).to be_a(Hash)
        expect(result.keys.size).to eq(2)
      end

      it "converts plan IDs to BSON::ObjectId" do
        result = controller.send(:parse_employer_costs_from_params)
        expect(result.keys.first).to be_a(BSON::ObjectId)
      end

      it "converts costs to floats" do
        result = controller.send(:parse_employer_costs_from_params)
        expect(result.values).to all(be_a(Float))
      end

      it "correctly parses cost values" do
        result = controller.send(:parse_employer_costs_from_params)
        expect(result[plan_id_1]).to eq(150.50)
        expect(result[plan_id_2]).to eq(200.75)
      end

      context "with invalid format" do
        before do
          allow(controller).to receive(:params).and_return(ActionController::Parameters.new(employer_costs: "invalid:format:extra"))
          allow(Rails.logger).to receive(:error)
        end

        it "returns empty hash on error" do
          result = controller.send(:parse_employer_costs_from_params)
          expect(result).to eq({})
        end

        it "logs the error" do
          controller.send(:parse_employer_costs_from_params)
          expect(Rails.logger).to have_received(:error).with(/Error parsing employer costs/)
        end
      end

      context "with missing employer_costs param" do
        before do
          allow(controller).to receive(:params).and_return(ActionController::Parameters.new({}))
          allow(Rails.logger).to receive(:error)
        end

        it "handles missing param gracefully" do
          result = controller.send(:parse_employer_costs_from_params)
          expect(result).to eq({})
        end
      end
    end
  end
end
