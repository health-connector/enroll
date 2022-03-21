# frozen_string_literal: true

class ExtractContinuousShoppingParams
  include Interactor

  before do
    context.fail!(message: "missing cart enrollment id") unless  enrollment_id.present?
  end

  def call
    context.employee_role = hbx_enrollment.employee_role
    context.market_kind = hbx_enrollment.kind
    context.enrollment_kind = hbx_enrollment.enrollment_kind
    context.effective_on = hbx_enrollment.effective_on
  rescue StandardError => _e
    context.fail!(message: "invalid cart enrollment id")
  end

  def hbx_enrollment
    @hbx_enrollment ||= HbxEnrollment.find(enrollment_id)
  end

  def enrollment_id
    context.cart.collect{|_k,v| v[:id]}.first
  end
end