# frozen_string_literal: true

FactoryBot.define do
  factory :plan_design_proposal, class: 'SponsoredBenefits::Organizations::PlanDesignProposal' do

    trait :with_profile do
      after(:create) do |proposal, _evaluator|
        create(:shop_cca_employer_profile, plan_design_proposal: proposal)
      end
    end
  end
end