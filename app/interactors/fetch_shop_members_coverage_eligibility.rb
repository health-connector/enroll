# frozen_string_literal: true

class FetchShopMembersCoverageEligibility
  include Interactor

  before do
    context.fail if context.benefit_group.blank?
  end

  def call
    context.coverage_eligibility = {benefit_group.id.to_s => member_coverage_eligibilities(benefit_group)}
  end

  def member_coverage_eligibilities(benefit_group)
    context.family_members.each_with_object({}) do |family_member, output|
      member_eligibilities = shop_health_and_dental_attributes(family_member, benefit_group)
      output[family_member.id.to_s] = member_eligibilities
    end
  end

  def shop_health_and_dental_attributes(family_member, benefit_group)
    is_health_coverage = eligibility_checker(benefit_group, :health).can_cover?(family_member, coverage_start)
    is_dental_coverage = eligibility_checker(benefit_group, :dental).can_cover?(family_member, coverage_start)

    [is_health_coverage, is_dental_coverage]
  end

  def benefit_group
    context.benefit_group
  end

  def employee_role
    context.employee_role
  end

  def coverage_family_members_for_cobra
    context.coverage_family_members_for_cobra
  end

  def coverage_start
    context.new_effective_on
  end

  def primary_relationship
    family_member.primary_relationship
  end

  def eligibility_checker(benefit_group, coverage_kind)
    shop_benefit_eligibilty_checker_for(benefit_group, coverage_kind)
  end

  def shop_eligibility_checkers
    {}
  end

  def shop_benefit_eligibilty_checker_for(benefit_package, coverage_kind)
    shop_eligibility_checkers[coverage_kind] ||= GroupSelectionEligibilityChecker.new(benefit_package, coverage_kind)
  end
end