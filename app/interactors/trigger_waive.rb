# frozen_string_literal: true

class TriggerWaive
  include Interactor

  def call
    return unless waiver_enrollment.present? && waiver_enrollment.may_waive_coverage?

    waiver_enrollment.waiver_reason = context.waiver_reason
    waiver_enrollment.waive_enrollment
  end

  private

  def waiver_enrollment
    context.waiver_enrollment
  end
end