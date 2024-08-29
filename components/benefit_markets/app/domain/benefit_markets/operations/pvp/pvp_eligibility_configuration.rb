# frozen_string_literal: true

module BenefitMarkets
  module Operations
    module Pvp
      # Overrides top level eligibility_configuration for feature specific configurations
      class PvpEligibilityConfiguration < ::Operations::Eligible::EligibilityConfiguration
        attr_reader :subject, :effective_date

        def initialize(params)
          @subject = params[:subject]
          @effective_date = params[:effective_date]

          super()
        end

        def key
          :cca_shop_pvp_eligibility
        end

        def title
          "CCA Shop PVP Eligibility"
        end

        def grants
          [["pvp_in_rating_area", "Premium Value Product In Given RatingArea"]]
        end
      end
    end
  end
end
