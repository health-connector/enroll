# frozen_string_literal: true

FactoryBot.define do
  factory :family do
    association :person
    sequence(:e_case_id) {|n| "abc#{n}12xyz#{n}"}
    renewal_consent_through_year  { 2017 }
    submitted_at { Time.now }
    updated_at { "user" }

    transient do
      people { [] }
    end

    trait :with_primary_family_member do
      family_members do
        [FactoryBot.build(:family_member, family: self,
                                          is_primary_applicant: true, is_active: true, person: person)]
      end
    end

    trait :with_family_members do
      family_members { people.map{|person| FactoryBot.build(:family_member, family: self, is_primary_applicant: (self.person == person), is_active: true, person: person) }}
    end

    after(:create) do |f, _evaluator|
      f.households.first.add_household_coverage_member(f.family_members.first)
      f.save
    end

    trait :with_primary_family_member_and_dependent do
      family_members do
        [
          FactoryBot.build(:family_member, family: self, is_primary_applicant: true, is_active: true, person: person),
          FactoryBot.build(:family_member, family: self, is_primary_applicant: false, is_active: true, person: FactoryBot.create(:person, first_name: "John", last_name: "Doe")),
          FactoryBot.build(:family_member, family: self, is_primary_applicant: false, is_active: true, person:  FactoryBot.create(:person, first_name: "Alex", last_name: "Doe"))
        ]
      end
      before(:create)  do |family, _evaluator|
        family.dependents.each do |dependent|
          family.relate_new_member(dependent.person, "child")
        end
      end
    end
  end
end

FactoryBot.define do
  factory(:individual_market_family, class: Family) do

    transient do
      primary_person    { FactoryBot.create(:person, :with_consumer_role) }
      significant_other { FactoryBot.create(:person, :with_consumer_role, gender: "female") }
      disabled_child    do
        FactoryBot.create(:person, :with_consumer_role,
                          is_disabled: true,
                          dob: (Date.today - 27.years))
      end
    end

    family_members do
      [
        FactoryBot.build(:family_member, family: self, is_primary_applicant: true, is_active: true,
                                         person: primary_person)
      ]
    end

    after(:create) do |f, _evaluator|
      f.households.first.add_household_coverage_member(f.family_members.first)
    end

    factory :individual_market_family_with_spouse do

      after(:create) do |f, evaluator|
        spouse = FactoryBot.create(:family_member, family: f, is_primary_applicant: false,
                                                   is_active: true, person: evaluator.significant_other)
        f.active_household.add_household_coverage_member(spouse)
      end

    end

    factory :individual_market_family_with_disabled_overage_child do

      after(:create) do |f, evaluator|
        child = FactoryBot.create(:family_member, family: f, is_primary_applicant: false,
                                                  is_active: true, person: evaluator.disabled_child)
        f.active_household.add_household_coverage_member(child)
      end

    end
  end
end
