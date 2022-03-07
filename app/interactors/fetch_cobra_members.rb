# frozen_string_literal: true

class FetchCobraMembers
  include Interactor

  def call
    return unless context.market_kind == 'shop'
    return nil if context.change_plan == 'change_by_qle' || context.enrollment_kind == 'sep'
    return unless employee_role.present? && employee_role.is_cobra_status?

    context.coverage_family_members_for_cobra = shop_market_enrollment.hbx_enrollment_members.map(&:family_member) if shop_market_enrollment.present?
  end

  def employee_role
    context.employee_role
  end

  def shop_market_enrollment
    enrollments = context.primary_family.active_household.hbx_enrollments.shop_market if context.primary_family.present?
    @shop_market_enrollment ||= enrollments&.enrolled_and_renewing&.effective_desc&.detect(&:may_terminate_coverage?)
  end
end