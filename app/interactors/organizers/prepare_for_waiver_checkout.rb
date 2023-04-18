# frozen_string_literal: true

module Organizers
  class PrepareForWaiverCheckout
    include Interactor::Organizer

    organize [FindEnrollmentAndAssociations,
              BuildJsonForWaiverCheckout]
  end
end