# frozen_string_literal: true

require 'rails_helper'

module SponsoredBenefits
  include ApplicationHelper
  RSpec.describe Organizations::PlanDesignProposals::PlansController, type: :controller, dbclean: :around_each do

    describe ".index" do
      let!(:current_effective_date) { (TimeKeeper.date_of_record + 2.months).beginning_of_month }
      let!(:issuer_profile) { FactoryGirl.create(:benefit_sponsors_organizations_issuer_profile) }
      let!(:county_zip) do
        FactoryGirl.create(:benefit_markets_locations_county_zip,
                           county_name: 'Middlesex',
                           zip: '01754',
                           state: 'MA')
      end
      let!(:service_area) do
        FactoryGirl.create(:benefit_markets_locations_service_area,
                           county_zip_ids: [county_zip.id],
                           active_year: current_effective_date.year)
      end

      let!(:hps) do
        FactoryGirl.create_list(:benefit_markets_products_health_products_health_product,
                                5,
                                application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
                                product_package_kinds: [:single_issuer, :metal_level, :single_product],
                                service_area: service_area,
                                issuer_profile_id: issuer_profile.id,
                                metal_level_kind: :gold)
      end

      before do
        hps.each do |hp|
          qhp = FactoryGirl.build(:products_qhp, active_year: hp.active_year, standard_component_id: hp.hios_base_id)
          csv = qhp.qhp_cost_share_variances.build(hios_plan_and_variant_id: hp.hios_id)
          ded1 = csv.qhp_deductibles.build(in_network_tier_1_individual: "$100", in_network_tier_1_family: "$100 | $200", deductible_type: "Medical EHB Deductible")
          ded1.save
          csv.save
          doc = FactoryGirl.build(:document, identifier: '1:1#1')
          hp.sbc_document = doc
          hp.save!
          FactoryGirl.create(:plan, hios_id: hp.hios_id)
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

  end
end
