# frozen_string_literal: true

class BuildJsonForWaiverCheckout
  include Interactor

  def call
    context.json = {enrollment: context.hbx_enrollment,
                    employer_profile: context.employer_profile,
                    employee_role: context.hbx_enrollment.employee_role,
                    coverage_kind: context.coverage_kind,
                    enrollment_kind: context.enrollment_kind,
                    market_kind: context.market_kind,
                    family: context.family,
                    event: context.event,
                    waiver_reason: context[:params][:waiver_reason]
                  }
  end
end