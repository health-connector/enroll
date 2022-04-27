# frozen_string_literal: true

class FetchParamsForEligibleSelection
  include Interactor

  before do
    context.fail!(message: "no previous enrollment present") unless context.previous_hbx_enrollment.present?
  end

  def call
    context.benefit_package = context.previous_hbx_enrollment.sponsored_benefit_package
  end
end