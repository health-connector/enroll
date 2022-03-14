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
              BuildEnrollmentForShop,
              CheckEmployerBenefitsForEmployee,
              HireAndAssignCurrentUserBrokerAgency,
              AssignShopAttributesToEnrollments,
              PersistEnrollmentAndAssignToAssignments,
              BuildJsonPayloadForShopping]
  end
end