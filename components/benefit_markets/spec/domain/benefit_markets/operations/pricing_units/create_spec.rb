# frozen_string_literal: true

require "rails_helper"

RSpec.describe BenefitMarkets::Operations::PricingUnits::Create, dbclean: :after_each do

  let(:ee_pricing_unit) do
    {
      "_id" => BSON::ObjectId('5b044e499f880b5d6f36c78d'),
      "created_at" => nil,
      "discounted_above_threshold" => nil,
      "display_name" => "Employee",
      "eligible_for_threshold_discount" => false,
      "name" => "employee",
      "order" => 0,
      "updated_at" => nil
    }
  end

  let(:member_relationship_maps) {[_id: BSON::ObjectId.new, relationship_name: :employee, operator: :==, count: 1]}

  context 'sending required parameters for pricing unit', dbclean: :after_each do

    [:single_issuer, :metal_level, :multi_product].each do |package_kind|

      let!(:params) do
        ee_pricing_unit_params = package_kind == :single_product ? ee_pricing_unit.merge(member_relationship_maps: member_relationship_maps) : ee_pricing_unit
        { pricing_unit_params: ee_pricing_unit_params, package_kind: package_kind, product_kind: :health }
      end

      it "should be successful for #{package_kind} package_kind" do
        expect(subject.call(**params).success?).to be_truthy
      end

      it "should create appropriate pricing unit entity for #{package_kind} package_kind" do
        if package_kind == 'single_product' && Settings.site.key == :cca && params[:product_kind] == :health
          expect(subject.call(**params).success).to be_a BenefitMarkets::Entities::TieredPricingUnit
        else
          expect(subject.call(**params).success).to be_a BenefitMarkets::Entities::RelationshipPricingUnit
        end
      end
    end
  end
end