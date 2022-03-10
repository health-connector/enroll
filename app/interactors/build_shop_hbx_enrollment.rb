# frozen_string_literal: true

class BuildShopHbxEnrollment
  include Interactor

  def call
    e_builder = ::EnrollmentShopping::EnrollmentBuilder.new(context.coverage_household, context.employee_role, context.coverage_kind)
    e_builder.build_new_enrollment(family_member_ids: context.family_member_ids, is_qle: nil, shop_under_current: context.shop_under_current, shop_under_future: context.shop_under_future,  optional_effective_on: nil)
  end
end