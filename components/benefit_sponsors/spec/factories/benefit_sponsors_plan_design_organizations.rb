# frozen_string_literal: true

FactoryBot.define do
  factory :plan_design_organization, class: 'BenefitSponsors::Organizations::PlanDesignOrganization' do
    legal_name  { "Turner Agency, Inc" }
    dba         { "Turner Brokers" }

    fein do
      Forgery('basic').text(:allow_lower => false,
                            :allow_upper => false,
                            :allow_numeric => true,
                            :allow_special => false, :exactly => 9)
    end

    trait :with_profile do
      after(:create) do |organization, _evaluator|
        create(:plan_design_proposal, :with_profile, plan_design_organization: organization)
      end
    end
  end
end


