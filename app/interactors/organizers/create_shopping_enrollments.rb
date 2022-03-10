# frozen_string_literal: true

module Organizers
  class CreateShoppingEnrollments
    include Interactor::Organizer

    organize [FindPerson,
              FindPrimaryFamily,
              FetchCoverageHouseholdAndFamilyMembers,
              FetchEmployeeRole,
              CheckEligibilityForNewEnrollment,
              BuildHbxEnrollment,
              FetchShopBenefit,
              CalculateNewEffectiveOn,
              FetchShopMembersCoverageEligibility]
  end
end