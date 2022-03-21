# frozen_string_literal: true

class FindEnrollmentAndAssociations
  include Interactor

  def call
    return  if @context.shop_for.nil? && @context.go_to_coverage_selection == true

    context.fail!(message: "no hbx enrollment found for given id") unless hbx_enrollment.present?
    return unless hbx_enrollment.is_shop?


    hbx_enrollment.set_special_enrollment_period
    find_associated_fields
    context.hbx_enrollment = hbx_enrollment
  end

  private

  def find_associated_fields
    context.coverage_kind = hbx_enrollment.coverage_kind
    context.enrollment_kind = hbx_enrollment.enrollment_kind
    context.market_kind = hbx_enrollment.kind
    context.family = hbx_enrollment.family
    context.use_family_deductable = hbx_enrollment.hbx_enrollment_members.count > 1
    context.enrollable = hbx_enrollment.can_complete_shopping?(qle: hbx_enrollment.is_special_enrollment?)
    context.waivable = hbx_enrollment.can_waive_enrollment?
    context.employer_profile = hbx_enrollment.employer_profile
  end

  def hbx_enrollment
    @hbx_enrollment ||= HbxEnrollment.find(hbx_enrollment_id)
  end

  def hbx_enrollment_id
    context.shop_attributes&.dig(:enrollment_id) || context.hbx_enrollment_id || context.params&.dig(:id) || context.params&.dig(:enrollment_id)
  end
end