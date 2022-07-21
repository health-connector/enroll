# frozen_string_literal: true

module Organizers
  class Receipt
    include Interactor::Organizer

    organize [FindEnrollmentAndAssociations,
              FindProduct,
              BuildMemberGroup]
  end
end