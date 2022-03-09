# frozen_string_literal: true

class FetchCoverageHouseholdAndFamilyMembers
  include Interactor

  before do
    context.fail!(message: "missing person id in params") unless context.primary_family.present?
  end

  def call
    immediate_family_coverage_household = context.primary_family.active_household.immediate_family_coverage_household

    if immediate_family_coverage_household
      family_members = immediate_family_coverage_household.coverage_household_members.map(&:family_member).flatten
      family_members = family_members.select{|fm| fm.is_active?}
      context.family_members = family_members
      context.coverage_household = immediate_family_coverage_household
    else
      context.fail!(message: "no immediate_family_coverage_household for this family")
    end
  end
end