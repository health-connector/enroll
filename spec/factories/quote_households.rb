# frozen_string_literal: true

FactoryBot.define do
  factory :quote_household do
    sequence(:family_id, &:to_s)
    quote_benefit_group_id {@qbg_id_testing}
  end

  trait :with_members do
    after(:create) do |qh, _evaluator|
      create_list(:quote_member,1, quote_household: qh)
    end
  end

  trait :with_quote_family do
    after(:create) do |qh, _evalulator|
      create(:quote_member, quote_household: qh)
      create(:quote_spouse, quote_household: qh)
    end
  end
end