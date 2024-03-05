FactoryBot.define do
  factory :benefit_markets_pricing_models_pricing_model, class: 'BenefitMarkets::PricingModels::PricingModel' do

    name  { "FEHB Employer Price Model" }

    transient do
      package_kind { :single_product }
      product_kind { :health }
    end

    after(:build) do |pricing_model, evaluator|

      pricing_model.member_relationships = [

        BenefitMarkets::PricingModels::MemberRelationship.new(
          relationship_name: "employee",
          relationship_kinds: ["self"]
          ),
        BenefitMarkets::PricingModels::MemberRelationship.new(
          relationship_name: "spouse",
          relationship_kinds: ["spouse", "life_partner"]
          ),
        BenefitMarkets::PricingModels::MemberRelationship.new(
          relationship_name: "dependent",
          age_threshold: 27,
          age_comparison: :<,
          relationship_kinds: ["child", "adopted_child","foster_child","stepchild", "ward"]
          ),
        BenefitMarkets::PricingModels::MemberRelationship.new(
          relationship_name: "dependent",
          age_threshold: 27,
          age_comparison: :>=,
          disability_qualifier: true,
          relationship_kinds: ["child", "adopted_child","foster_child","stepchild", "ward"]
          )
      ]

      relationship_pricing_units = [
        BenefitMarkets::PricingModels::RelationshipPricingUnit.new(
          name: "employee",
          display_name: "employee",
          order: 0,
          discounted_above_threshold: 4,
          eligible_for_threshold_discount: true
          ),
        BenefitMarkets::PricingModels::RelationshipPricingUnit.new(
          name: "spouse",
          display_name: "spouse",
          order: 1,
          discounted_above_threshold: 4,
          eligible_for_threshold_discount: true
          ),
        BenefitMarkets::PricingModels::RelationshipPricingUnit.new(
          name: "dependent",
          display_name: "dependent",
          order: 2,
          discounted_above_threshold: 4,
          eligible_for_threshold_discount: true
          )
      ]

      tierd_pricing_units = [
        BenefitMarkets::PricingModels::TieredPricingUnit.new(
          name: "employee_only",
          display_name: "Employee Only",
          order: 0,
          member_relationship_maps: [
            BenefitMarkets::PricingModels::MemberRelationshipMap.new(relationship_name: :employee, operator: :==, count: 1),
            BenefitMarkets::PricingModels::MemberRelationshipMap.new(relationship_name: :spouse, operator: :==, count: 0),
            BenefitMarkets::PricingModels::MemberRelationshipMap.new(relationship_name: :dependent, operator: :==, count: 0)
          ]
        ),
        BenefitMarkets::PricingModels::TieredPricingUnit.new(
          name: "employee_and_spouse",
          display_name: "Employee and Spouse",
          order: 1,
          member_relationship_maps: [
            BenefitMarkets::PricingModels::MemberRelationshipMap.new(relationship_name: :employee, operator: :==, count: 1),
            BenefitMarkets::PricingModels::MemberRelationshipMap.new(relationship_name: :spouse, operator: :==, count: 1),
            BenefitMarkets::PricingModels::MemberRelationshipMap.new(relationship_name: :dependent, operator: :==, count: 0)
          ]
        ),
        BenefitMarkets::PricingModels::TieredPricingUnit.new(
          name: "employee_and_one_or_more_dependents",
          display_name: "Employee and Dependents",
          order: 2,
          member_relationship_maps: [
            BenefitMarkets::PricingModels::MemberRelationshipMap.new(relationship_name: :employee, operator: :==, count: 1),
            BenefitMarkets::PricingModels::MemberRelationshipMap.new(relationship_name: :spouse, operator: :==, count: 0),
            BenefitMarkets::PricingModels::MemberRelationshipMap.new(relationship_name: :dependent, operator: :==, count: 1)
          ]
        ),
        BenefitMarkets::PricingModels::TieredPricingUnit.new(
          name: "family",
          display_name: "Family",
          order: 2,
          member_relationship_maps: [
            BenefitMarkets::PricingModels::MemberRelationshipMap.new(relationship_name: :employee, operator: :==, count: 1),
            BenefitMarkets::PricingModels::MemberRelationshipMap.new(relationship_name: :spouse, operator: :==, count: 1),
            BenefitMarkets::PricingModels::MemberRelationshipMap.new(relationship_name: :dependent, operator: :==, count: 1)
          ]
        )
      ]

      simple_calculator = "::BenefitSponsors::PricingCalculators::ShopSimpleListBillPricingCalculator"
      tierd_calculator = "::BenefitSponsors::PricingCalculators::CcaCompositeTieredPriceCalculator"

      pricing_model.pricing_units, pricing_model.price_calculator_kind =
        if evaluator.package_kind == :single_product && evaluator.product_kind == :health
          [tierd_pricing_units, tierd_calculator]
        else
          [relationship_pricing_units, simple_calculator]
        end
    end
  end
end