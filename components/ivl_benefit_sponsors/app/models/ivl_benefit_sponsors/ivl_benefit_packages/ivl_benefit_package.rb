module IvlBenefitSponsors
  class IvlBenefitPackages::IvlBenefitPackage
    include Mongoid::Document
    include Mongoid::Timestamps

    BENEFIT_BEGIN_AFTER_EVENT_OFFSET_KINDS = [0, 30, 60, 90]
    BENEFIT_EFFECTIVE_DATE_KINDS      = %w(date_of_event first_of_month)
    BENEFIT_TERMINATION_DATE_KINDS    = %w(date_of_event end_of_month)

    # Premium Credit Strategies
    # 1. Unassisted: subscriber is responsible for total premium cost
    # 2. Employer fixed cost: employer fixed dollar amount applied toward employee's total premium cost
    # 3. Employee fixed cost: employee costs defined, regardless of age, and employer pays the difference
    # 4. Allocated lump sum credit (e.g. APTC): fixed dollar amount apportioned among eligible relationship categories
    # 5. Percentage contribution: contribution ratio applied to each eligible relationship category
    # 6. Indexed percentage contribution (e.g. DCHL SHOP method): using selected reference benefit, contribution ratio applied to each eligible relationship category
    # 7. Federal Employee Health Benefits (FEHB - congress): percentage contribution, with employer cost cap

    PREMIUM_CREDIT_STRATEGY_KINDS  = %w(unassisted employer_fixed_cost employee_fixed_cost allocated_lump_sum_credit
                                        percentage_contribution indexed_percentage_contribution, federal_employee_health_benefit)

    embedded_in :ivl_benefit_application, class_name: "::IvlBenefitSponsors::IvlBenefitApplications::IvlBenefitApplication",
                inverse_of: :ivl_benefit_packages

    embeds_one :ivl_benefit_element_eligibility_group,
                class_name: "::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup"
    accepts_nested_attributes_for :benefit_eligibility_element_group

    field :title, type: String, default: ""

    field :benefit_begin_after_event_offsets, type: Array, default: []
    field :benefit_effective_dates,           type: Array, default: []
    field :benefit_termination_dates,         type: Array, default: []

    field :elected_premium_credit_strategy,   type: String
    field :index_benefit_id,                  type: BSON::ObjectId
    field :benefit_ids,                       type: Array, default: []

    delegate :start_on, :end_on, to: :ivl_benefit_application

    delegate :market_places, :enrollment_periods, :family_relationships, :benefit_categories,
             :incarceration_status, :age_range, :citizenship_status, :residency_status, :ethnicity, :cost_sharing,
             to: :ivl_benefit_element_eligibility_group

    delegate :market_places=, :enrollment_periods=, :family_relationships=, :benefit_categories=,
             :incarceration_status=, :age_range=, :citizenship_status=, :residency_status=, :ethnicity=,
             to: :ivl_benefit_element_eligibility_group

    after_initialize :initialize_dependent_models

    validates :elected_premium_credit_strategy,
      allow_blank: false,
      inclusion: {
        in: PREMIUM_CREDIT_STRATEGY_KINDS,
        message: "%{value} is not a valid premium credit strategy kind"
      }

    def initialize_dependent_models
      build_ivl_benefit_element_eligibility_group if ivl_benefit_element_eligibility_group.nil?
    end

    def effective_year
      start_on.year
    end
  end
end
