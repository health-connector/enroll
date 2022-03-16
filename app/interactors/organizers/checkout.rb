# frozen_string_literal: true

module Organizers
  class Checkout
    include Interactor::Organizer

    organize [FindEnrollmentAndAssociations,
              FindProduct,
              AssignParamsForCheckout,
              VerifyAndSetMemberCoverageStartOn,
              PersistEnrollment,
              BuildJsonForReceipt]
  end
end