# frozen_string_literal: true

class FetchShopMembersCoverageEligibility
  include Interactor

  before do
    context.fail!(message: "no benefit_package") if context.benefit_package.blank?
  end

  def call
    context.coverage_eligibility = {benefit_package.id.to_s => member_coverage_eligibilities}
  end

  def member_coverage_eligibilities
    context.family_members.each_with_object({}) do |family_member, output|
      member_eligibilities = shop_health_and_dental_attributes(family_member)
      output[family_member.id.to_s] = member_eligibilities
    end
  end

  def shop_health_and_dental_attributes(family_member)
    is_health_coverage = benefit_eligibilty_checker_for(:health).can_cover?(family_member, coverage_start)
    is_dental_coverage = benefit_eligibilty_checker_for(:dental).can_cover?(family_member, coverage_start)

    [is_health_coverage, is_dental_coverage]
  end

  def benefit_package
    context.benefit_package
  end

  def employee_role
    context.employee_role
  end

  def coverage_family_members_for_cobra
    context.coverage_family_members_for_cobra
  end

  def coverage_start
    context.new_effective_on || Date.strptime(context.params[:new_effective_on], '%m/%d/%Y')
  end

  def shop_eligibility_checkers
    {}
  end

  def benefit_eligibilty_checker_for(coverage_kind)
    shop_eligibility_checkers[coverage_kind] ||= GroupSelectionEligibilityChecker.new(benefit_package, coverage_kind)
  end
end