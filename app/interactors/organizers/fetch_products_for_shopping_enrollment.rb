# frozen_string_literal: true

module Organizers
  class FetchProductsForShoppingEnrollment
    include Interactor::Organizer

    organize [AnalyzeCartForNextShoppingFlow,
              FindEnrollmentAndAssociations,
              FetchEnrolledEnrollmentsForSamePackage,
              FetchShoppingProducts,
              BuildLookupTable]
  end
end