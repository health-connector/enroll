FactoryGirl.define do
  factory :benefit_sponsors_organizations_profile, class: 'BenefitSponsors::Organizations::Profile' do

    contact_method :paper_and_electronic

    transient do
      office_locations_count 1
      office_location_kind :primary
    end

    after(:build) do |profile, evaluator|
      create_list(:benefit_sponsors_locations_office_location, evaluator.office_locations_count, evaluator.office_location_kind, profile: profile)
    end

  end
end
