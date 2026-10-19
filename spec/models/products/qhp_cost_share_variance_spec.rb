# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Products::QhpCostShareVariance, dbclean: :around_each do
  let(:standard_component_id) { "11821MA0040003" }
  let(:year) { 2027 }

  let!(:qhp) do
    Products::Qhp.create!(
      standard_component_id: standard_component_id,
      active_year: year,
      issuer_id: "11821",
      state_postal_code: "MA",
      plan_marketing_name: "Dental Plan",
      hios_product_id: "11821MA004",
      network_id: "N001",
      service_area_id: "MAS001",
      is_new_plan: "No",
      plan_type: "PPO",
      metal_level: "Dental",
      qhp_or_non_qhp: "off_the_exchange",
      emp_contribution_amount_for_hsa_or_hra: "0",
      child_only_offering: "Allows Adult and Child-Only",
      plan_effective_date: "01/01/2027",
      out_of_country_coverage: "No",
      out_of_service_area_coverage: "No",
      national_network: "No",
      qhp_cost_share_variances: [
        Products::QhpCostShareVariance.new(
          hios_plan_and_variant_id: "#{standard_component_id}-01",
          plan_marketing_name: "Dental Plan"
        )
      ]
    )
  end

  describe ".find_qhp_cost_share_variances" do
    context "when coverage_kind is 'Dental' (capitalized, as sent by call sites that hardcode it)" do
      it "appends the -01 variant suffix and finds the cost share variance" do
        result = described_class.find_qhp_cost_share_variances([standard_component_id], year, "Dental")

        expect(result.size).to eq(1)
        expect(result.first.hios_plan_and_variant_id).to eq("#{standard_component_id}-01")
      end
    end

    context "when coverage_kind is 'dental' (lowercase, as sent by Product#kind.to_s)" do
      it "still appends the -01 variant suffix and finds the cost share variance" do
        result = described_class.find_qhp_cost_share_variances([standard_component_id], year, "dental")

        expect(result.size).to eq(1)
        expect(result.first.hios_plan_and_variant_id).to eq("#{standard_component_id}-01")
      end
    end

    context "when coverage_kind is health" do
      it "does not append a suffix and returns no match for a dental-suffixed id" do
        result = described_class.find_qhp_cost_share_variances([standard_component_id], year, "Health")

        expect(result).to be_empty
      end
    end
  end
end
