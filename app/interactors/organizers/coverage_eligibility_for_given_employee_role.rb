# frozen_string_literal: true

module Organizers
  class CoverageEligibilityForGivenEmployeeRole
    include Interactor::Organizer

    organize [FindPerson,
              FindPrimaryFamily,
              FetchCoverageHouseholdAndFamilyMembers,
              FetchEmployeeRole,
              FetchShopBenefit,
              CalculateNewEffectiveOn,
              FetchShopMembersCoverageEligibility]
  end
end