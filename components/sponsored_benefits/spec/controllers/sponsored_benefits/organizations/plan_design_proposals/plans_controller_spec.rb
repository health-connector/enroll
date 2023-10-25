# frozen_string_literal: true

require 'rails_helper'

module SponsoredBenefits
  include ApplicationHelper
  RSpec.describe Organizations::PlanDesignProposals::PlansController, type: :controller, dbclean: :around_each do

    describe ".index" do
      let!(:current_effective_date) { (TimeKeeper.date_of_record + 2.months).beginning_of_month }
      let!(:issuer_profile) { FactoryBot.create(:benefit_sponsors_organizations_issuer_profile) }
      let!(:county_zip) do
        FactoryBot.create(:benefit_markets_locations_county_zip,
                           county_name: 'Middlesex',
                           zip: '01754',
                           state: 'MA')
      end
      let!(:service_area) do
        FactoryBot.create(:benefit_markets_locations_service_area,
                           county_zip_ids: [county_zip.id],
                           active_year: current_effective_date.year)
      end

      let!(:hps) do
        FactoryBot.create_list(:benefit_markets_products_health_products_health_product,
                                5,
                                application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
                                product_package_kinds: [:single_issuer, :metal_level, :single_product],
                                service_area: service_area,
                                issuer_profile_id: issuer_profile.id,
                                metal_level_kind: :gold)
      end

      before do
        hps.each do |hp|
          qhp = FactoryBot.build(:products_qhp, active_year: hp.active_year, standard_component_id: hp.hios_base_id)
          csv = qhp.qhp_cost_share_variances.build(hios_plan_and_variant_id: hp.hios_id)
          ded1 = csv.qhp_deductibles.build(in_network_tier_1_individual: "$100", in_network_tier_1_family: "$100 | $200", deductible_type: "Medical EHB Deductible")
          ded1.save
          csv.save
          doc = FactoryBot.build(:document, identifier: '1:1#1')
          hp.sbc_document = doc
          hp.save!
          FactoryBot.create(:plan, hios_id: hp.hios_id, active_year: current_effective_date.year)
        end
      end

      it "returns formatted deductible values" do
        plans = Plan.all.to_a
        deductibles = subject.instance_eval { plan_deductible_values(plans) }

        expect(deductibles[plans[0].id][:deductible]).to eq('$100')
        expect(deductibles[plans[1].id][:family_deductible]).to eq('$200')
        expect(deductibles[plans[2].id][:rx_deductible]).to eq('N/A')
        expect(deductibles[plans[3].id][:rx_family_deductible]).to eq('N/A')
      end
    end

    describe ".index" do
      routes { SponsoredBenefits::Engine.routes }
      let!(:current_effective_date) { (TimeKeeper.date_of_record + 2.months).beginning_of_month }
      let!(:user) { FactoryBot.create(:user) }
      let!(:person) { FactoryBot.create(:person, :with_broker_role, user: user) }
      let(:broker_role) { person.broker_role }
      let!(:broker_agency_profile) { FactoryBot.create(:benefit_sponsors_organizations_broker_agency_profile) }
      let(:plan_design_organization) { FactoryBot.create(:sponsored_benefits_plan_design_organization) }
      let(:carrier_profile) { FactoryBot.create(:carrier_profile) }
      let(:plan_1) { FactoryBot.create(:plan, premium_tables: [premium_table_1], carrier_profile_id: carrier_profile.id, active_year: 2022) }
      let!(:product_1) { FactoryBot.create(:benefit_markets_products_health_products_health_product, hios_id: plan_1.hios_id, application_period: ('2022-01-01'.to_date..'2022-12-31'.to_date)) }
      let(:premium_table_1) { PremiumTable.new(age: 12, cost: 12, start_on: '2022-07-01'.to_date, end_on: '2022-09-30'.to_date) }

      let(:plan_2) { FactoryBot.create(:plan, premium_tables: [premium_table_2], carrier_profile_id: carrier_profile.id, active_year: 2022) }
      let!(:product_2) { FactoryBot.create(:benefit_markets_products_health_products_health_product, hios_id: plan_2.hios_id, application_period: ('2022-01-01'.to_date..'2022-12-31'.to_date)) }
      let(:premium_table_2) { PremiumTable.new(age: 12, cost: 12, start_on: '2022-01-01'.to_date, end_on: '2022-03-31'.to_date) }

      let(:valid_params) do
        {
          plan_design_organization_id: plan_design_organization.id,
          selected_carrier_level: 'single_carrier',
          carrier_id: carrier_profile.id,
          active_year: 2022,
          quote_effective_date: '2022-07-01'.to_date
        }
      end

      context "when future a plan is not offering rates" do
        before do
          allow(controller).to receive(:current_user).and_return(user)
          allow(controller).to receive(:current_person).and_return(person)
          allow(broker_role).to receive(:benefit_sponsors_broker_agency_profile_id).and_return(broker_agency_profile.id)
          allow_any_instance_of(::Queries::EmployerPlanOfferings).to receive(:single_carrier_offered_health_plans).and_return([plan_1, plan_2])
          [plan_1, plan_2].each do |plan|
            hios_base_id, _csr_variant_id = plan.hios_id.split("-")
            qhp = FactoryBot.build(:products_qhp, active_year: plan.active_year, standard_component_id: hios_base_id)
            csv = qhp.qhp_cost_share_variances.build(hios_plan_and_variant_id: plan.hios_id)
            csv.qhp_deductibles.build(in_network_tier_1_individual: "$100", in_network_tier_1_family: "$100 | $200", deductible_type: "Medical EHB Deductible")
            qhp.save!
          end
        end
        it "should not appear in the list of plans during that effective on" do
          xhr :get, :index, valid_params
          expect(assigns[:plans].count).to eq 1
        end
      end
    end
  end
end
