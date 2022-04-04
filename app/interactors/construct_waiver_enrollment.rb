# frozen_string_literal: true

class ConstructWaiverEnrollment
  include Interactor

  def call
    if hbx_enrollment.shopping?
      context.waiver_enrollment = hbx_enrollment
      return
    end

    context.waiver_enrollment = nil if hbx_enrollment.waiver_enrollment_present?
    context.waiver_enrollment = hbx_enrollment.construct_waiver_enrollment(context.waiver_reason)
  end

  private

  def hbx_enrollment
    context.hbx_enrollment
  end
end