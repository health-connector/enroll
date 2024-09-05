# frozen_string_literal: true

FactoryBot.define do
  factory :sponsored_benefits_organizations_issuer_profile, class: 'SponsoredBenefits::Organizations::IssuerProfile' do
    organization            { build(:benefit_sponsors_organizations_exempt_organization) }
  end
end
