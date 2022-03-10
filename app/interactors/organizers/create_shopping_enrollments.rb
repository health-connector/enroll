# frozen_string_literal: true

module Organizers
  class CreateShoppingEnrollments
    include Interactor::Organizer

    organize [FindPerson,
              FindPrimaryFamily,
              FetchCoverageHouseholdAndFamilyMembers,
              AssignCommonParamsForMemberSelection,
              FindPreviousHbxEnrollment,
              FetchEmployeeRole,
              CheckEligibilityForNewEnrollment,
              BuildShopHbxEnrollment,
              CheckEmployerBenefitsForEmployee,
              HireAndAssignCurrentUserBrokerAgency,
              PersistHbxEnrollment,
              AssignShopAttributesToEnrollments,
              FetchShopBenefit,
              CalculateNewEffectiveOn,
              FetchShopMembersCoverageEligibility]
  end
end