# frozen_string_literal: true

class BuildEnrollmentForShop
  include Interactor

  def call
    return unless context.market_kind == 'shop'

    context.shopping_enrollments = []
    context.params[:shopping_members].each do |coverage_kind, enrolling_hash|
      enrolling_hash.each do |enrolling_type, member_hash|
        next if enrolling_type == 'waive'

        enrolling_family_members = member_hash.values.collect{|id| BSON::ObjectId.from_string(id)}
        e_builder = ::EnrollmentShopping::EnrollmentBuilder.new(context.coverage_household, context.employee_role, coverage_kind)
        new_enrollment = if context.hbx_enrollment.present?
                           e_builder.build_change_enrollment(family_member_ids: enrolling_family_members, is_qle: context.qle, optional_effective_on: context.optional_effective_on, previous_enrollment: context.hbx_enrollment)
                         else
                           e_builder.build_new_enrollment(family_member_ids: enrolling_family_members,
                                                          is_qle: context.qle,
                                                          shop_under_current: context.shop_under_current,
                                                          shop_under_future: context.shop_under_future,
                                                          optional_effective_on: context.optional_effective_on)
                         end
        context.shopping_enrollments << new_enrollment
      end
    end
  end
end