# frozen_string_literal: true

FactoryBot.define do
  factory :sponsored_benefits_plan_design_organization, class: 'SponsoredBenefits::Organizations::PlanDesignOrganization' do
    legal_name  { "Turner Agency, Inc" }
    dba         { "Turner Brokers" }

    sequence :sic_code do |n|
      "765#{n}"
    end

    sponsor_profile_id { BSON::ObjectId.new }

    owner_profile_id { BSON::ObjectId.new }

    fein do
      Forgery('basic').text(:allow_lower => false,
                            :allow_upper => false,
                            :allow_numeric => true,
                            :allow_special => false, :exactly => 9)
    end

    office_locations do
      [build(:sponsored_benefits_office_location, :primary)]
    end

    trait :with_profile do
      after(:create) do |organization, _evaluator|
        create(:plan_design_proposal, :with_profile, plan_design_organization: organization)
      end
    end
  end
end


