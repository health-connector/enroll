# frozen_string_literal: true

module Organizers
  class MembersSelectionPrevaricationAdapter
    include Interactor::Organizer

    organize [FindPerson,
              FindPrimaryFamily,
              FindImmediateFamilyCoverageHousehold,
              AssignParamsToContext,
              AssignPreviousHbxEnrollment,
              FetchShoppingRole,
              DisableMarketKinds,
              FetchMarketAndCoverageKindFromEnrollment,
              SelectMarketKind,
              SetIvlBenefit,
              AssignChangePlanForShop,
              FetchShopBenefit]
  end
end