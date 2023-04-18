# frozen_string_literal: true

class BuildEnrollmentForShop
  include Interactor

  def call
    return unless context.market_kind == 'shop'

    context.shopping_enrollments = []
    context.enrollments_to_waive = []
    context.params[:shopping_members].each do |coverage_kind, enrolling_hash|
      enrolling_hash = enrolling_hash.each_with_object({}){|(key,value), output| (output[value] ||= []) << key.to_s }

      enrolling_hash.each do |enrolling_type, shopping_family_member_ids|
        next if enrolling_type == 'waive' && enrolling_hash['enroll'].present?

        if enrolling_hash['enroll'].blank?
          context.enrollments_to_waive << coverage_kind
          context.fail!(message: "Please select a reason for health waiver") if context.params[:waiver_reason].blank? && coverage_kind == "health"
        end

        shopping_family_member_ids = shopping_family_member_ids.collect{|id| BSON::ObjectId.from_string(id)}
        e_builder = ::EnrollmentShopping::EnrollmentBuilder.new(context.coverage_household, context.employee_role, coverage_kind)
        new_enrollment = if context.hbx_enrollment.present?
                           e_builder.build_change_enrollment(family_member_ids: shopping_family_member_ids, is_qle: context.qle, optional_effective_on: context.optional_effective_on, previous_enrollment: context.hbx_enrollment)
                         else
                           e_builder.build_new_enrollment(family_member_ids: shopping_family_member_ids,
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