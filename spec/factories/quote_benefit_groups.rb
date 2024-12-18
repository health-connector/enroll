# frozen_string_literal: true

FactoryBot.define do
  factory :quote_benefit_group do
    title { "My Benefit Group" }
    default  { true }
    plan_option_kind { "single_carrier" }

    published_reference_plan { FactoryBot.create(:plan).id }
    published_lowest_cost_plan { published_reference_plan }
    published_highest_cost_plan { published_reference_plan }

    #after(:create) do |q, evaluator|
    #  build(:quote_relationship_benefit, quote_benefit_group: q)
    #end

  end
end
