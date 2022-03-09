# frozen_string_literal: true

class FetchShopBenefit
  include Interactor

  before do
    context.fail if context.benefit_group.blank?
  end

  def call
    context.family_members.each do |family_member|
      shop_health_and_dental_attributes(family_member)
    end
  end

  def shop_health_and_dental_attributes(family_member)
    health_offered_relationship_benefits, dental_offered_relationship_benefits = health_and_dental_relationship_benefits

    if health_offered_relationship_benefits.present?
      is_health_coverage = if benefit_group.sole_source?
                             composite_relationship_check(health_offered_relationship_benefits, family_member)
                           else
                             coverage_relationship_check(health_offered_relationship_benefits, family_member)
                           end

      is_health_coverage = coverage_family_members_for_cobra.include?(family_member) if is_health_coverage && coverage_family_members_for_cobra.present?
    end

    if health_offered_relationship_benefits.present?
      is_dental_coverage = coverage_relationship_check(dental_offered_relationship_benefits, family_member)
      is_dental_coverage = coverage_family_members_for_cobra.include?(family_member) if is_dental_coverage && coverage_family_members_for_cobra.present?
    end

    [is_health_coverage, is_dental_coverage]
  end

  def health_and_dental_relationship_benefits
    health_offered_relationship_benefits = benefit_group.sole_source? ? composite_benefits : traditional_benefits
    dental_offered_relationship_benefits = benefit_group.dental_relationship_benefits.select(&:offered).map(&:relationship) if is_eligible_for_dental?(@change_plan, @hbx_enrollment)

    [health_offered_relationship_benefits, dental_offered_relationship_benefits]
  end

  def coverage_relationship_check(offered_relationship_benefits, family_member)
    relationship = PlanCostDecorator.benefit_relationship(primary_relationship)
    relationship = "child_over_26" if relationship == "child_under_26" && (calculate_age_by_dob(family_member.dob) > 26 || (new_effective_on.is_a?(Date) && new_effective_on >= family_member.dob + 26.years))

    offered_relationship_benefits.include? relationship
  end

  def composite_relationship_check(offered_relationship_benefits, family_member)
    relationship = CompositeRatedPlanCostDecorator.benefit_relationship(primary_relationship)
    relationship = "child_over_26" if direct_realation_to_primary == "child" && calculate_age_by_dob(family_member.dob) >= 26 && new_effective_on >= family_member.dob + 26.years

    offered_relationship_benefits.include? relationship
  end

  def composite_benefits
    benefit_group.composite_tier_contributions.select(&:offered).map(&:composite_rating_tier)
  end

  def traditional_benefits
    benefit_group.relationship_benefits.select(&:offered).map(&:relationship)
  end

  def is_eligible_for_dental?(change_plan, enrollment)
    renewing_bg = employee_role.census_employee.renewal_published_benefit_group
    active_bg = employee_role.census_employee.active_benefit_group

    if change_plan != "change_by_qle"
      if change_plan == "change_plan" && enrollment.present? && enrollment.is_shop?
        enrollment.benefit_group.is_offering_dental?
      elsif employee_role.can_enroll_as_new_hire?
        active_bg.present? && active_bg.is_offering_dental?
      else
        (renewing_bg || active_bg).present? && (renewing_bg || active_bg).is_offering_dental?
      end
    else
      effective_on = employee_role.person.primary_family.current_sep.effective_on

      if renewing_bg.present? && is_covered_plan_year?(renewing_bg.benefit_application, effective_on)
        renewing_bg.is_offering_dental?
      elsif active_bg.present?
        active_bg.is_offering_dental?
      end
    end
  end

  def is_covered_plan_year?(benefit_application, effective_on)
    (benefit_application.start_on.beginning_of_day..benefit_application.end_on.end_of_day).cover? effective_on
  end

  def benefit_group
    context.benefit_group
  end

  def     
    context.employee_role
  end

  def coverage_family_members_for_cobra
    context.coverage_family_members_for_cobra
  end

  def new_effective_on
    context.new_effective_on
  end

  def primary_relationship
    family_member.primary_relationship
  end

end