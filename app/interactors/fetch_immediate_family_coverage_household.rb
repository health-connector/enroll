# frozen_string_literal: true

class FetchImmediateFamilyCoverageHousehold
  include Interactor

  before do
    context.fail!(message: "missing person id in params") unless context.primary_family.present?
  end

  def call
    immediate_family_coverage_household = context.primary_family.active_household.immediate_family_coverage_household

    if immediate_family_coverage_household
      context.coverage_household = immediate_family_coverage_household
    else
      context.fail!(message: "no immediate_family_coverage_household for this family")
    end
  rescue StandardError => e
    context.fail!(message: "invalid ID")
  end
end