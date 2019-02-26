FactoryGirl.define do
  factory :person do
    # name_pfx 'Mr'
    first_name 'John'
    # middle_name 'X'
    sequence(:last_name) {|n| "Smith#{n}" }
    # name_sfx 'Jr'
    dob "1972-04-04".to_date
    is_incarcerated false
    is_active true
    gender "male"

    transient do
      benefit_sponsor_employer_profile_id nil
    end

    trait :with_broker_role do
      after(:create) do |p, evaluator|
        create_list(:broker_role, 1, person: p)
      end
    end

    trait :with_family do
      after :create do |person|
        family = FactoryGirl.create :family, :with_primary_family_member, person: person
      end
    end

    trait :with_work_phone do
      phones { [FactoryGirl.build(:phone, kind: "work") ] }
    end

    trait :with_work_email do
      emails { [FactoryGirl.build(:email, kind: "work") ] }
    end

    trait :with_employer_staff_role do
      after(:create) do |p, evaluator|
        if evaluator.benefit_sponsor_employer_profile_id
          create_list(:benefit_sponsor_employer_staff_role, 1, person: p, benefit_sponsor_employer_profile_id: evaluator.benefit_sponsor_employer_profile_id)
        else
          create_list(:benefit_sponsor_employer_staff_role, 1, person: p)
        end
      end
    end

    trait :with_hbx_staff_role do
      after(:create) do |p, evaluator|
        create_list(:benefit_sponsor_hbx_staff_role, 1, person: p)
      end
    end

  end
end
