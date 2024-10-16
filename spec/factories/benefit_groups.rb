# frozen_string_literal: true

FactoryBot.define do
  factory :benefit_group do
    plan_year
    composite_tier_contributions do
      [
      FactoryBot.build(:composite_tier_contribution, benefit_group: self),
      FactoryBot.build(:composite_tier_contribution, benefit_group: self, composite_rating_tier: 'family', employer_contribution_percent: 40.0)

    ]
    end
    relationship_benefits do
      [
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :employee,                   premium_pct: 80, employer_max_amt: 1000.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :spouse,                     premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :domestic_partner,           premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :child_under_26,             premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :disabled_child_26_and_over, premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :child_26_and_over,          premium_pct:  0, employer_max_amt:    0.00, offered: false)
      ]
    end
    effective_on_kind { "date_of_hire" }
    terminate_on_kind { "end_of_month" }
    plan_option_kind { "single_plan" }
    description { "my first benefit group" }
    effective_on_offset { 0 }
    default { false }
    reference_plan_id {FactoryBot.create(:plan, :with_rating_factors, :with_premium_tables)._id}
    elected_plan_ids { [reference_plan_id]}
    elected_dental_plan_ids { [reference_plan_id] }
    employer_max_amt_in_cents { 100_000 }

    trait :premiums_for_2015 do
      reference_plan_id {FactoryBot.create(:plan, :with_rating_factors, :premiums_for_2015)._id}
    end
  end

  trait :with_valid_dental do
    dental_relationship_benefits do
      [
      FactoryBot.build_stubbed(:dental_relationship_benefit, benefit_group: self, relationship: :employee,                   premium_pct: 49, employer_max_amt: 1000.00),
      FactoryBot.build_stubbed(:dental_relationship_benefit, benefit_group: self, relationship: :spouse,                     premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build_stubbed(:dental_relationship_benefit, benefit_group: self, relationship: :domestic_partner,           premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build_stubbed(:dental_relationship_benefit, benefit_group: self, relationship: :child_under_26,             premium_pct: 40, employer_max_amt:  200.00, offered: false),
      FactoryBot.build_stubbed(:dental_relationship_benefit, benefit_group: self, relationship: :disabled_child_26_and_over, premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build_stubbed(:dental_relationship_benefit, benefit_group: self, relationship: :child_26_and_over,          premium_pct:  0, employer_max_amt:    0.00, offered: false)
      ]
    end

    dental_plan_option_kind { "single_plan" }
    dental_reference_plan_id {FactoryBot.create(:plan, :with_rating_factors, :with_premium_tables)._id}
    elected_dental_plan_ids { [dental_reference_plan_id]}
    employer_max_amt_in_cents { 100_000 }
  end

  trait :with_dental_benefits do
    dental_relationship_benefits do
      [
        FactoryBot.build(:dental_relationship_benefit, benefit_group: self, relationship: :employee,                   premium_pct: 49, employer_max_amt: 1000.00),
        FactoryBot.build(:dental_relationship_benefit, benefit_group: self, relationship: :spouse,                     premium_pct: 40, employer_max_amt:  200.00),
        FactoryBot.build(:dental_relationship_benefit, benefit_group: self, relationship: :domestic_partner,           premium_pct: 40, employer_max_amt:  200.00),
        FactoryBot.build(:dental_relationship_benefit, benefit_group: self, relationship: :child_under_26,             premium_pct: 40, employer_max_amt:  200.00, offered: false),
        FactoryBot.build(:dental_relationship_benefit, benefit_group: self, relationship: :disabled_child_26_and_over, premium_pct: 40, employer_max_amt:  200.00),
        FactoryBot.build(:dental_relationship_benefit, benefit_group: self, relationship: :child_26_and_over,          premium_pct:  0, employer_max_amt:    0.00, offered: false)
    ]
    end

    dental_plan_option_kind { "single_plan" }
    dental_reference_plan_id {FactoryBot.create(:plan, :with_premium_tables)._id}
    elected_dental_plan_ids { [dental_reference_plan_id]}
    employer_max_amt_in_cents { 100_000 }
  end

  trait :invalid_employee_relationship_benefit do
    relationship_benefits do
      [
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :employee,                   premium_pct: 49, employer_max_amt: 1000.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :spouse,                     premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :domestic_partner,           premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :child_under_26,             premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :disabled_child_26_and_over, premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :child_26_and_over,          premium_pct:  0, employer_max_amt:    0.00, offered: false)
      ]
    end
  end
end

FactoryBot.define do
  factory :benefit_group_congress, class: BenefitGroup do
    plan_year
    is_congress { true }
    effective_on_kind { "first_of_month" }
    terminate_on_kind { "end_of_month" }
    plan_option_kind { "metal_level" }
    description { "Congress Standard" }
    effective_on_offset { 30 }
    default { true }

    reference_plan_id {FactoryBot.create(:plan, :with_rating_factors, :with_premium_tables)._id}
    elected_plan_ids { [reference_plan_id]}

    relationship_benefits do
      [
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :employee,                   premium_pct: 75, employer_max_amt: 1000.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :spouse,                     premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :domestic_partner,           premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :child_under_26,             premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :disabled_child_26_and_over, premium_pct: 40, employer_max_amt:  200.00),
      FactoryBot.build(:relationship_benefit, benefit_group: self, relationship: :child_26_and_over,          premium_pct:  0, employer_max_amt:    0.00, offered: false)
      ]
    end
  end
end
