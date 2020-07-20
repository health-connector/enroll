class BenefitGroup

  include Mongoid::Document
  include Mongoid::Timestamps

  field :title, type: String
  field :description, type: String


  def self.find(id)
  end

  def monthly_max_employee_cost(coverage_kind = nil)
    monthly_employee_cost(coverage_kind).max
  end

  def targeted_census_employees
    target_object = persisted? ? self : plan_year.employer_profile
    target_object.census_employees
  end

  def employee_cost_for_plan(ce, plan = reference_plan)
    pcd = if @is_congress
      decorated_plan(plan, ce)
    elsif plan_option_kind == 'sole_source' && !plan.dental?
      CompositeRatedPlanCostDecorator.new(plan, self, effective_composite_tier(ce), ce.is_cobra_status?)
    else
      if plan.dental? && dental_reference_plan.present?
        PlanCostDecorator.new(plan, ce, self, dental_reference_plan)
      else
        PlanCostDecorator.new(plan, ce, self, reference_plan)
      end
    end
    pcd.total_employee_cost
  end

  def single_plan_type?
    plan_option_kind == "single_plan"
  end

  def is_default?
    default
  end

  def carriers_offered
    case plan_option_kind
    when "single_plan"
      Plan.where(id: reference_plan_id).pluck(:carrier_profile_id)
    when "sole_source"
      Plan.where(id: reference_plan_id).pluck(:carrier_profile_id)
    when "single_carrier"
      Plan.where(id: reference_plan_id).pluck(:carrier_profile_id)
    when "metal_level"
      Plan.where(:id => {"$in" => elected_plan_ids}).pluck(:carrier_profile_id).uniq
    end
  end

  def dental_carriers_offered
    return [] unless is_offering_dental?
    if dental_plan_option_kind == 'single_plan'
      Plan.where(:id => {"$in" => elected_dental_plan_ids}).pluck(:carrier_profile_id).uniq
    else
      Plan.where(id: dental_reference_plan_id).pluck(:carrier_profile_id)
    end
  end

  def elected_plans_by_option_kind
    @profile_and_service_area_pairs = CarrierProfile.carrier_profile_service_area_pairs_for(employer_profile, self.start_on.year)

    case plan_option_kind
    when "sole_source"
      Plan.where(id: reference_plan_id).first
    when "single_plan"
      Plan.where(id: reference_plan_id).first
    when "single_carrier"

      if carrier_for_elected_plan.blank?
        @carrier_for_elected_plan = reference_plan.carrier_profile_id if reference_plan.present?
      end
      carrier_profile_id = reference_plan.carrier_profile_id

      if constrain_service_areas?
        plans = Plan.check_plan_offerings_for_single_carrier # filter by vertical choice(as there should be no bronze plans for one carrier.)
        plans.valid_shop_health_plans_for_service_area("carrier", carrier_for_elected_plan, start_on.year, @profile_and_service_area_pairs.select { |pair| pair.first == carrier_profile_id }).to_a
      else
        Plan.valid_shop_health_plans("carrier", carrier_for_elected_plan, start_on.year).to_a
      end
      
    when "metal_level"
      if carrier_for_elected_plan.blank?
        carrier_for_elected_plan = reference_plan.carrier_profile_id if reference_plan.present?
      end    
      if constrain_service_areas?
        Plan.valid_shop_health_plans_for_service_area("carrier", carrier_for_elected_plan, start_on.year, @profile_and_service_area_pairs).select { |pair| pair.metal_level == reference_plan.metal_level }.to_a
      else
        Plan.valid_shop_health_plans("carrier", carrier_for_elected_plan, start_on.year).select { |pair| pair.metal_level == reference_plan.metal_level }.to_a
      end
    end
  end

  def elected_dental_plans_by_option_kind
    if dental_plan_option_kind == "single_carrier"
      Plan.by_active_year(self.start_on.year).shop_market.dental_coverage.by_carrier_profile(self.carrier_for_elected_dental_plan)
    else
      Plan.by_active_year(self.start_on.year).shop_market.dental_coverage
    end
  end

  def effective_title_by_offset
    case effective_on_offset
    when 0
      "First of the month following or coinciding with date of hire"
    when 1
      "First of the month following date of hire"
    when 30
      "First of the month following 30 days"
    when 60
      "First of the month following 60 days"
    end
  end

  def disable_benefits
    self.employer_profile.census_employees.each do |ce|
      benefit_group_assignments = ce.benefit_group_assignments.where(benefit_group_id: self.id)

      if benefit_group_assignments.present?
        benefit_group_assignments.each do |bga|
          bga.hbx_enrollments.each do |enrollment|
            enrollment.cancel_coverage! if enrollment.may_cancel_coverage?
          end
          bga.update(is_active: false) unless self.plan_year.is_renewing?
        end

        other_benefit_group = self.plan_year.benefit_groups.detect{ |bg| bg.id != self.id}

        if self.plan_year.is_renewing?
          # ce.add_renew_benefit_group_assignment(other_benefit_group)
          ce.add_renew_benefit_group_assignment([other_benefit_group])
        else
          ce.create_benefit_group_assignment([other_benefit_group])
        end
      end
    end

    self.is_active = false
  end

  # Interface for composite and list bill.
  # Defines the methods needed for calculation of both composite and list
  # bill values.

  # Provide the sic factor for this benefit group.
  def sic_factor_for(plan)
    if use_simple_employer_calculation_model?
      return 1.0
    end
    factor_carrier_id = plan.carrier_profile_id
    @scff_cache ||= Hash.new do |h, k|
      h[k] = lookup_cached_scf_for(k)
    end
    @scff_cache[factor_carrier_id]
  end

  def lookup_cached_scf_for(carrier_id)
    year = plan_year.start_on.year
    SicCodeRatingFactorSet.value_for(carrier_id, year, plan_year.sic_code)
  end

  # Provide the base factor for this composite rating tier.
  def composite_rating_tier_factor_for(composite_rating_tier, plan)
    factor_carrier_id = plan.carrier_profile_id
    lookup_key = [factor_carrier_id, composite_rating_tier]
    @crtbf_cache ||= Hash.new do |h, k|
      h[k] = lookup_cached_crtbf_for(k)
    end
    @crtbf_cache[lookup_key]
  end

  def lookup_cached_crtbf_for(carrier_tier_pair)
    year = plan_year.start_on.year
    CompositeRatingTierFactorSet.value_for(carrier_tier_pair.first, year, carrier_tier_pair.last)
  end

  # Provide the rating area value for this benefit group.
  def rating_area
    @rating_area ||= plan_year.rating_area
  end

  # Provide the participation rate factor for this group.
  def composite_participation_rate_factor_for(plan)
    factor_carrier_id = plan.carrier_profile_id
    @cprf_cache ||= Hash.new do |h, k|
      h[k] = lookup_cached_cprf_for(k)
    end
    @cprf_cache[factor_carrier_id]
  end

  def lookup_cached_cprf_for(carrier_id)
    year = plan_year.start_on.year
    EmployerParticipationRateRatingFactorSet.value_for(carrier_id, year, participation_rate * 100.0)
  end

  def targeted_census_employees_participation
    targeted_census_employees.select{|ce| ce.is_included_in_participation_rate?}
  end

  def participation_rate
    total_employees = targeted_census_employees_participation.count
    return(0.0) if total_employees < 1
    waived_and_active_count = if plan_year.estimate_group_size?
                          targeted_census_employees_participation.select{|ce| ce.expected_to_enroll_or_valid_waive?}.length
                        else
                          all_active_and_waived_health_enrollments.length
                        end
    waived_and_active_count/(total_employees * 1.0)
  end

  # Provide the group size factor for this benefit group.
  def group_size_factor_for(plan)
    if use_simple_employer_calculation_model?
      return 1.0
    end
    factor_carrier_id = plan.carrier_profile_id
    @gsf_cache ||= Hash.new do |h, k|
      h[k] = lookup_cached_gsf_for(k)
    end
    @gsf_cache[factor_carrier_id]
  end

  def lookup_cached_gsf_for(carrier_id)
    year = plan_year.start_on.year
    if plan_option_kind == "sole_source"
      EmployerGroupSizeRatingFactorSet.value_for(carrier_id, year, group_size_count)
    else
      EmployerGroupSizeRatingFactorSet.value_for(carrier_id, year, 1)
    end
  end

  # Provide the premium for a given composite rating tier.
  def composite_rating_tier_premium_for(composite_rating_tier)
    @crtp_cache ||= Hash.new do |h, k|
      h[k] = lookup_cached_crtp_for(k)
    end
    @crtp_cache[composite_rating_tier]
  end

  def lookup_cached_crtp_for(composite_rating_tier)
    ct_contribution = composite_tier_contributions.detect { |ctc| ctc.composite_rating_tier == composite_rating_tier }
    plan_year.estimate_group_size? ? ct_contribution.estimated_tier_premium : ct_contribution.final_tier_premium
  end

  # Provide the contribution factor for a given composite rating tier.
  def composite_employer_contribution_factor_for(composite_rating_tier)
    @cecf_cache ||= Hash.new do |h, k|
       h[k] = lookup_cached_eccf_for(k)
    end
    @cecf_cache[composite_rating_tier]
  end

  def lookup_cached_eccf_for(composite_rating_tier)
    ct_contribution = composite_tier_contributions.detect { |ctc| ctc.composite_rating_tier == composite_rating_tier }
    ct_contribution.contribution_factor
  end

  # Count of enrolled employees - either estimated or actual depending on plan
  # year status
  def group_size_count
    if plan_year.estimate_group_size?
      targeted_census_employees_participation.select { |ce| ce.expected_to_enroll? }.length
    else
      all_active_health_enrollments.length
    end
  end

  def composite_rating_enrollment_objects
    if plan_year.estimate_group_size?
      targeted_census_employees_participation.select { |ce| ce.expected_to_enroll? }
    else
      all_active_health_enrollments
    end
  end

  def all_active_and_waived_health_enrollments
    benefit_group_assignments.flat_map do |bga|
      bga.active_and_waived_enrollments.reject do |en|
        en.dental?
      end
    end
  end

  def renewal_elected_plan_ids
    start_on_year = (start_on.next_year).year
    if plan_option_kind == "single_carrier"
      Plan.by_active_year(start_on_year).shop_market.health_coverage.by_carrier_profile(reference_plan.carrier_profile).and(hios_id: /-01/).pluck(:_id)
    else
      if plan_option_kind == "metal_level"
        Plan.by_active_year(start_on_year).shop_market.health_coverage.by_metal_level(reference_plan.metal_level).and(hios_id: /-01/).pluck(:_id)
      else
        Plan.where(:id.in => elected_plan_ids).pluck(:renewal_plan_id).compact
      end
    end
  end

  def renewal_elected_dental_plan_ids
    return [] unless is_offering_dental?
    start_on_year = (start_on.next_year).year
    if plan_option_kind == "single_carrier"
      Plan.by_active_year(start_on_year).shop_market.dental_coverage.by_carrier_profile(dental_reference_plan.carrier_profile).pluck(:_id)
    else
      Plan.where(:id.in => elected_dental_plan_ids).pluck(:renewal_plan_id).compact
    end
  end

  def all_active_health_enrollments
    benefit_group_assignments.flat_map do |bga|
      bga.active_enrollments.reject do |en|
        en.dental?
      end
    end
  end

  def sole_source?
    plan_option_kind == "sole_source"
  end

  def build_estimated_composite_rates
    return(nil) unless sole_source?
    rate_calc = CompositeRatingBaseRatesCalculator.new(self, self.elected_plans.try(:first) || reference_plan)
    rate_calc.build_estimated_premiums
  end

  def estimate_composite_rates
    return(nil) unless sole_source?
    rate_calc = CompositeRatingBaseRatesCalculator.new(self, self.elected_plans.try(:first) || reference_plan)
    rate_calc.assign_estimated_premiums
  end

  def finalize_composite_rates
    return(nil) unless sole_source?
    rate_calc = CompositeRatingBaseRatesCalculator.new(self, self.elected_plans.first)
    rate_calc.assign_final_premiums
  end

  private

  def set_congress_defaults
    return true unless is_congress
    self.plan_option_kind = "metal_level"
    self.default = true

    # 2018 contribution schedule
    self.contribution_pct_as_int   = 75
    self.employee_max_amt = 496.71 if employee_max_amt == 0
    self.first_dependent_max_amt = 1063.83 if first_dependent_max_amt == 0
    self.over_one_dependents_max_amt = 1130.09 if over_one_dependents_max_amt == 0
  end

  def update_dependent_composite_tiers
    family_tier = self.composite_tier_contributions.where(composite_rating_tier: 'family')
    return unless family_tier.present?
    return if plan_year.is_conversion

    contribution = family_tier.first.employer_contribution_percent
    estimated_tier_premium = family_tier.first.estimated_tier_premium
    offered = family_tier.first.offered

    (CompositeRatingTier::NAMES - CompositeRatingTier::VISIBLE_NAMES).each do |crt|
      tier = self.composite_tier_contributions.find_or_initialize_by(
        composite_rating_tier: crt
      )
      tier.employer_contribution_percent = contribution
      tier.offered = offered
    end
  end

  def dollars_to_cents(amount_in_dollars)
    Rational(amount_in_dollars) * Rational(100) if amount_in_dollars
  end

  def cents_to_dollars(amount_in_cents)
    (Rational(amount_in_cents) / Rational(100)).to_f if amount_in_cents
  end

  def is_eligible_to_enroll_on?(date_of_hire, enrollment_date = TimeKeeper.date_of_record)

    # Length of time prior to effective date that EE may purchase plan
    Settings.aca.shop_market.earliest_enroll_prior_to_effective_on.days

    # Length of time following effective date that EE may purchase plan
    Settings.aca.shop_market.latest_enroll_after_effective_on.days

    # Length of time that EE may enroll following correction to Census Employee Identifying info
    Settings.aca.shop_market.latest_enroll_after_employee_roster_correction_on.days

  end

  # Non-congressional
  # pick reference plan
  # two pctages
  # toward employee
  # toward each dependent type

  # member level premium in reference plan, apply pctage by type, calc $$ amount.
  # may be applied toward and other offered plan
  # never pay more than premium per person
  # extra may not be applied toward other members

  def plan_integrity
    return if elected_plan_ids.blank?

    if (plan_option_kind == "single_plan") && (elected_plan_ids.first != reference_plan_id)
      self.errors.add(:elected_plans, "single plan must be the reference plan")
    end

    if (plan_option_kind == "single_carrier")
      if !(elected_plan_ids.include? reference_plan_id)
        self.errors.add(:elected_plans, "single carrier must include reference plan")
      end
      if elected_plans.detect { |plan| plan.carrier_profile_id != reference_plan.try(:carrier_profile_id) }
        self.errors.add(:elected_plans, "not all from the same carrier as reference plan")
      end
    end

    if (plan_option_kind == "metal_level") && !(elected_plan_ids.include? reference_plan_id)
      self.errors.add(:elected_plans, "not all of the same metal level as reference plan")
    end
  end

  def check_employer_contribution_for_employee
    start_on = self.plan_year.try(:start_on)
    return if start_on.try(:at_beginning_of_year) == start_on

    # all employee contribution < 50% for 1/1 employers
    if start_on.month == 1 && start_on.day == 1
    else
      if self.sole_source?
        unless composite_tier_contributions.present?
          self.errors.add(:composite_rating_tier, "Employer must set contribution percentages")
        else
          employee_tier = composite_tier_contributions.find_by(composite_rating_tier: 'employee_only')

          if aca_shop_market_employer_contribution_percent_minimum > (employee_tier.try(:employer_contribution_percent) || 0)
            self.errors.add(:composite_tier_contributions,
            "Employer contribution for employee must be ≥ #{aca_shop_market_employer_contribution_percent_minimum}%")
          else
            family_tier = composite_tier_contributions.find_by(composite_rating_tier: 'family')
            if family_tier.offered? &&
              (family_tier.try(:employer_contribution_percent) || 0) < aca_shop_market_employer_family_contribution_percent_minimum
                self.errors.add(:composite_tier_contributions, "Employer contribution for family plans must be ≥ #{aca_shop_market_employer_family_contribution_percent_minimum}")
            end
          end
        end
      else
        if relationship_benefits.present? && (relationship_benefits.find_by(relationship: "employee").try(:premium_pct) || 0) < aca_shop_market_employer_contribution_percent_minimum
          self.errors.add(:relationship_benefits, "Employer contribution must be ≥ #{aca_shop_market_employer_contribution_percent_minimum}% for employee")
        end
      end
    end
  end

  def check_offered_for_employee
    if relationship_benefits.present? && (relationship_benefits.find_by(relationship: "employee").try(:offered) != true)
      self.errors.add(:relationship_benefits, "employee must be offered")
    end
  end
end
