require 'active_support/concern'

module SponsoredBenefits
  module Concerns::AcaRatingAreaConfigConcern
    extend ActiveSupport::Concern

    included do
      delegate :market_rating_areas, to: :class
      delegate :use_simple_employer_calculation_model?, to: :class
      delegate :general_agency_enabled?, to: :class
    end

    class_methods do
      def market_rating_areas
        @@market_rating_areas ||= Settings.aca.rating_areas
      end

      def general_agency_enabled?
        @@general_agency_enabled ||= Settings.aca.general_agency_enabled
      end

      def use_simple_employer_calculation_model?
        @@use_simple_employer_calculation_model ||= (Settings.aca.use_simple_employer_calculation_model.to_s.downcase == "true")
      end
    end
  end
end
