# frozen_string_literal: true

class FindEnrollment
  include Interactor

  def call
    context.fail!(message: "no hbx enrollment found for given id") unless hbx_enrollment.present?
    return unless hbx_enrollment.is_shop?

    context.hbx_enrollment = hbx_enrollment
  end

  private

  def hbx_enrollment
    @hbx_enrollment ||= HbxEnrollment.find(hbx_enrollment_id)
  end

  def hbx_enrollment_id
    context.shop_attributes&.dig(:enrollment_id) || context.hbx_enrollment_id || context.params&.dig(:id) || context.params&.dig(:enrollment_id)
  end
end