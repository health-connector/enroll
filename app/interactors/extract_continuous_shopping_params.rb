# frozen_string_literal: true

class ExtractContinuousShoppingParams
  include Interactor

  before do
    context.fail!(message: "missing cart enrollment id") unless  enrollment_id.present?
  end

  def call
    return unless hbx_enrollment.present?

    context.employee_role_id = hbx_enrollment.employee_role.id
    context.person_id = hbx_enrollment.employee_role.person.id
    context.market_kind = "shop" # This is considered as param from UI, Passing this as default shop
    context.enrollment_kind = hbx_enrollment.enrollment_kind
    context.new_effective_on = hbx_enrollment.effective_on
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