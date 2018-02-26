FactoryGirl.define do
  factory :notices_employer_profile, class: EmployerProfile do
    organization { FactoryGirl.build(:notice_organization, add: add) }
    entity_kind "c_corporation"
    sic_code '1111'
    transient do
      start_on TimeKeeper.date_of_record.next_month.next_month.beginning_of_month
      plan_year_state 'draft'
      renewal_plan_year_state 'renewing_draft'
      with_dental false
      add "MA"
    end

    trait :add do
      add "NOT MA"
    end

    trait :adds do
      add "MA"
    end
  end

  factory :notice_organization, class: Organization do
    transient do
      add "MA"
    end
    legal_name { Forgery(:name).company_name }
    dba { legal_name }
    office_locations  { 
      if add == "MA"
        [FactoryGirl.build(:office_location, :primary), FactoryGirl.build(:office_location)]
      elsif add == "NOT MA"
        [FactoryGirl.build(:office_location, :primary, :add), FactoryGirl.build(:office_location)]
      end
    }

    fein do
      Forgery('basic').text(:allow_lower   => false,
                            :allow_upper   => false,
                            :allow_numeric => true,
                            :allow_special => false, :exactly => 9)
    end
    before :create do |organization, evaluator|
      organization.employer_profile = FactoryGirl.create :notices_employer_profile
    end
  end

  factory :notice_custom_plan_year, class: PlanYear do
    transient do
      renewing false
      with_dental false
      ref_plan_id "cp"
    end

    employer_profile
    start_on TimeKeeper.date_of_record.beginning_of_month
    end_on { start_on + 1.year - 1.day }
    open_enrollment_start_on { start_on - 2.month }
    imported_plan_year true
    fte_count { 5 }

    open_enrollment_end_on do
      end_date = renewing ? Settings.aca.shop_market.renewal_application.monthly_open_enrollment_end_on : Settings.aca.shop_market.open_enrollment.monthly_end_on
      Date.new(open_enrollment_start_on.year, open_enrollment_start_on.month, end_date)
    end
    after(:create) do |custom_plan_year, evaluator|
      if evaluator.with_dental
        create(:benefit_group, :with_valid_dental, plan_year: custom_plan_year)
      else
        create(:notice_benefit_group, plan_year: custom_plan_year, title: "Benefit group #{Forgery('basic').text(:allow_lower   => false,
                                                                                                                 :allow_upper   => false,
                                                                                                                 :allow_numeric => true,
                                                                                                                 :allow_special => false, :exactly => 2)}",
                                                                   description: "My #{Forgery('basic').text(:allow_lower   => false,
                                                                                                            :allow_upper   => false,
                                                                                                            :allow_numeric => true,
                                                                                                            :allow_special => false, :exactly => 2)} Benefit group",
                                                                    reference_plan_id: Plan.find(evaluator.ref_plan_id).id)
      end
    end
  end

  factory :notice_benefit_group, class: BenefitGroup do
    plan_year
    composite_tier_contributions { [
      FactoryGirl.build(:composite_tier_contribution, benefit_group: self),
      FactoryGirl.build(:composite_tier_contribution, benefit_group: self, composite_rating_tier: 'family', employer_contribution_percent: 40.0)

    ] }
    relationship_benefits { [
      FactoryGirl.build(:relationship_benefit, benefit_group: self, relationship: :employee,                   ),
      FactoryGirl.build(:relationship_benefit, benefit_group: self, relationship: :spouse,                     ),
      FactoryGirl.build(:relationship_benefit, benefit_group: self, relationship: :domestic_partner,           ),
      FactoryGirl.build(:relationship_benefit, benefit_group: self, relationship: :child_under_26,             ),
      FactoryGirl.build(:relationship_benefit, benefit_group: self, relationship: :child_26_and_over,          offered: false),
      ] }
    effective_on_kind "first_of_month"
    terminate_on_kind "end_of_month"
    plan_option_kind "single_carrier"
    description "my first benefit group"
    effective_on_offset 0
    default false
    elected_plan_ids { [ self.reference_plan_id ]}
  end
end