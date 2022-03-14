# frozen_string_literal: true

class FetchEnrolledEnrollmentsForSamePackage
  include Interactor

  def call
    return if @context.shop_for.nil? && @context.go_to_coverage_selection == false
    enrolled_plans = context.family.active_household.hbx_enrollments.enrolled_and_renewing.by_coverage_kind(context.coverage_kind)

      bg_ids = context.hbx_enrollment.sponsored_benefit_package.benefit_application.benefit_packages.map(&:id)
      enrolled_plans = enrolled_plans.where(:sponsored_benefit_package_id.in => bg_ids)

    context.enrolled_hbx_enrollment_plan_ids = enrolled_plans.collect(&:product_id)
  end
end