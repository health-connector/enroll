# frozen_string_literal: true

require 'rails_helper'
require "#{SponsoredBenefits::Engine.root}/spec/shared_contexts/sponsored_benefits"

# The single plan view (ContributionsController#index) and the compare view
# (PlanComparisonsController#new) must show the same Estimated Maximum Monthly Employer Cost
# for the same plan, benefit model and contribution percentages.
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

    let(:office_location) { plan_design_proposal.profile.primary_office_location }
    let!(:rating_area) do
      FactoryBot.create(
        :rating_area,
        zip_code: office_location.address.zip,
        county_name: office_location.address.county,
        active_years: [current_effective_date.year]
      )
    end

    let!(:plans) do
      FactoryBot.create_list(:plan, 3, :with_complex_premium_tables, :with_rating_factors, coverage_kind: 'health', active_year: current_effective_date.year)
    end
    let(:plan) { plans.first }
    let(:qhps) { plans.map { |p| double("Products::QhpCostShareVariance", plan: p) } }

    # One employee in each composite rating tier (employee only, + spouse, + children, family)
    let!(:census_employees) do
      employee = -> { FactoryBot.create(:plan_design_census_employee, benefit_sponsorship_id: benefit_sponsorship.id) }
      child = { first_name: 'Kid', last_name: 'Vedder', employee_relationship: 'child_under_26', dob: TimeKeeper.date_of_record - 10.years }

      [
        employee.call,
        employee.call.tap { |ce| ce.census_dependents.create!(first_name: 'Spouse', last_name: ce.last_name, employee_relationship: 'spouse', dob: ce.dob) },
        employee.call.tap { |ce| ce.census_dependents.create!(child) },
        employee.call.tap do |ce|
          ce.census_dependents.create!(first_name: 'Spouse', last_name: ce.last_name, employee_relationship: 'spouse', dob: ce.dob)
          ce.census_dependents.create!(child)
        end
      ]
    end

    let(:relationship_pcts) do
      { 'employee' => 100, 'spouse' => 80, 'domestic_partner' => 50, 'child_under_26' => 60, 'child_26_and_over' => 0 }
    end

    let(:relationship_benefits_attributes) do
      relationship_pcts.each.with_index.with_object({}) do |((relationship, pct), index), attrs|
        attrs[index.to_s] = { relationship: relationship, premium_pct: pct, offered: relationship != 'child_26_and_over' }
      end
    end

    # Single plan view: buildBenefitGroupParams() sends all four tiers, the hidden ones copy the family percent
    let(:composite_tier_contributions_attributes) do
      %w[employee_only family employee_and_spouse employee_and_one_or_more_dependents].each.with_index.with_object({}) do |(tier, index), attrs|
        attrs[index.to_s] = { composite_rating_tier: tier, employer_contribution_percent: 70, offered: true }
      end
    end

    # Compare view: the form only renders the visible tiers, hidden tiers are posted as a bare id
    let(:form_composite_tier_contributions_attributes) do
      composite_tier_contributions_attributes.slice('0', '1').merge(
        '2' => { id: BSON::ObjectId.new.to_s },
        '3' => { id: BSON::ObjectId.new.to_s }
      )
    end

    def benefit_group_attributes(plan_option_kind, composite_tiers = composite_tier_contributions_attributes)
      attrs = { reference_plan_id: plan.id.to_s, plan_option_kind: plan_option_kind }
      if plan_option_kind == 'sole_source'
        attrs.merge(composite_tier_contributions_attributes: composite_tiers)
      else
        attrs.merge(relationship_benefits_attributes: relationship_benefits_attributes)
      end
    end

    # What ContributionsController#index does for the single plan view
    def single_plan_cost(plan_option_kind)
      group = benefit_application.benefit_groups.build(benefit_group_attributes(plan_option_kind))
      group.build_estimated_composite_rates if group.sole_source?
      group.set_bounding_cost_plans
      svc = SponsoredBenefits::Services::PlanCostService.new(benefit_group: group)
      svc.monthly_employer_contribution_amount
    end

    # What the compare button sends (serialized benefit group form fields)
    def compare_params(plan_option_kind)
      attributes = benefit_group_attributes(plan_option_kind, form_composite_tier_contributions_attributes)
      attributes[:relationship_benefits_attributes] ||= relationship_benefits_attributes
      prefix = %w[profile benefit_sponsorship benefit_application benefit_group]
      {
        plan_design_proposal_id: plan_design_proposal.id,
        plans: plans.map { |p| p.id.to_s },
        sort_by: '',
        elected_plan_kind: plan_option_kind,
        reference_plan_id: plan.id.to_s,
        forms_plan_design_proposal: prefix.reverse.inject(attributes) { |inner, key| { key => inner } },
        format: :js
      }
    end

    before do
      allow_any_instance_of(SponsoredBenefits::Organizations::PlanDesignOrganization).to receive(:is_renewing_employer?).and_return(false)
      benefit_application
      Caches::PlanDetails.load_record_cache! if Caches::PlanDetails.respond_to?(:load_record_cache!)
      sign_in user
      allow(::Products::QhpCostShareVariance).to receive(:find_qhp_cost_share_variances).and_return(qhps)
    end

    %w[single_plan single_carrier metal_level sole_source].each do |plan_option_kind|
      it "shows the same employer cost for #{plan_option_kind} in single plan and compare views" do
        expected = single_plan_cost(plan_option_kind)
        expect(expected).to be > 0

        get :new, params: compare_params(plan_option_kind), xhr: true

        expect(assigns(:employer_costs)[plan.id].to_f).to eq(expected.to_f)
      end
    end
  end
end
