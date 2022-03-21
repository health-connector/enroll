# frozen_string_literal: true

module Organizers
  class EligibleCoverageSelectionForNew
    include Interactor::Organizer

    organize [FindPerson,
      FindPrimaryFamily,
      FetchCoverageHouseholdAndFamilyMembers,
      FindPreviousHbxEnrollment,
      FetchParamsForEligibleSelection,
      AssignCommonParamsForMemberSelection,
      AssignNewParamsForMemberSelection,
      FetchShopMembersCoverageEligibility]
  end
end