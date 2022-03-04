# frozen_string_literal: true

module Organizers
  class MembersSelectionPrevaricationAdapter
    include Interactor::Organizer

    organize [FindPerson,
              FindPrimaryFamily,
              FetchImmediateFamilyCoverageHousehold,
              AssignParamsToContext,
              AssignPreviousHbxEnrollment,
              FetchShoppingRole,
              DisableMarketKinds,
              FetchMarketAndCoverageKindFromEnrollment,
              SelectMarketKind,
              FetchIvlBenefit,
              AssignChangePlanForShop,
              FetchShopBenefit,
              CalculateNewEffectiveOn,
              FetchCobraMembers,
              CanWaive]
  end
end