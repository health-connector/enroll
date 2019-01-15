FactoryGirl.define do
  factory :benefit_sponsors_benefit_packages_benefit_package, class: 'BenefitSponsors::BenefitPackages::BenefitPackage' do

    benefit_application { create(:benefit_sponsors_benefit_application) }

    title "first benefit package"
    description "my first benefit package"
    probation_period_kind :first_of_month
    is_default false

    transient do
      health_sponsored_benefit true
      dental_sponsored_benefit false
      product_package nil
      dental_product_package nil
    end

    after(:build) do |benefit_package, evaluator|
      
      if evaluator.health_sponsored_benefit
        build(:benefit_sponsors_sponsored_benefits_health_sponsored_benefit, benefit_package: benefit_package, product_package: evaluator.product_package)
      end

      if evaluator.dental_sponsored_benefit
        build(:benefit_sponsors_sponsored_benefits_dental_sponsored_benefit, benefit_package: benefit_package, product_package: evaluator.dental_product_package)
      end
    end

    trait :with_sponsored_benefits do |package|
      # It appears that we're not getting the sliders to set employer contributions
      # with selecting sliders here. Perhaps we can create the sponsored benefits
      # here as a trait and pass it through the worlds for features that way.
    end
  end
end