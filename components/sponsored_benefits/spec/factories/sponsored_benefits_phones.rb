# frozen_string_literal: true

FactoryBot.define do
  factory :sponsored_benefits_phone, class: 'SponsoredBenefits::Locations::Phone' do
    kind { 'home' }
    # sequence(:area_code, WrappingSequence.new(100, 999)) { |n| "#{n}"}
    area_code { 202 }
    sequence(:number, 1_111_111, &:to_s)
    sequence(:extension, &:to_s)

    trait :without_kind do
      kind { ' ' }
    end

    trait :without_area_code do
      area_code { ' ' }
    end

    trait :without_number do
      number { ' ' }
    end

    factory :sponsored_benefits_invalid_phone, traits: [:without_kind, :without_area_code, :without_number]
  end
end
