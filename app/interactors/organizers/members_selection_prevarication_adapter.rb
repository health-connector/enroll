# frozen_string_literal: true

module Organizers
  class MembersSelectionPrevaricationAdapter
    include Interactor::Organizer

    organize [FindPerson,
              FindPrimaryFamily,
              FetchCoverageHouseholdAndFamilyMembers,
              AssignParamsToContext,
              FindPreviousHbxEnrollment,
              FetchShoppingRole,
              DisableMarketKinds,
              FetchMarketAndCoverageKindFromEnrollment,
              SelectMarketKind,
              FetchIvlBenefit,
              AssignChangePlanForShop,
              FetchShopBenefit,
              CalculateNewEffectiveOn,
              FetchCobraMembers,
              CanWaive,
              FetchShopMembersCoverageEligibility]
  end
end