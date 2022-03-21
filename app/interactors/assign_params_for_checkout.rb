# frozen_string_literal: true

class AssignParamsForCheckout
  include Interactor

  def call
    context.qle = (hbx_enrollment.enrollment_kind == "special_enrollment")
    context.employee_is_shopping_before_hire = hbx_enrollment.employee_role.present? && hbx_enrollment.employee_role.hired_on > TimeKeeper.date_of_record
  end

  def hbx_enrollment
    @hbx_enrollment ||= context.hbx_enrollment
  end
end