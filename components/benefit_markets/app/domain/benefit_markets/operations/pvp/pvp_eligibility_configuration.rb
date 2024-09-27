# frozen_string_literal: true

module BenefitMarkets
  module Operations
    module Pvp
      # PvpEligibilityConfiguration defines feature-specific configurations
      # for PVP (Premium Value Product) eligibility in a CCA Shop Rating Area.
      #
      # This class overrides the top-level eligibility_configuration and
      # provides specific grants and rules for determining PVP eligibility.
      #
      # @example
      #   BenefitMarkets::Operations::Pvp::PvpEligibilityConfiguration.new(subject: subject, effective_date: date)
      class PvpEligibilityConfiguration < ::Operations::Eligible::EligibilityConfiguration
        attr_reader :subject, :effective_date

        # Initializes the PVP Eligibility Configuration
        #
        # @param [Hash] params Initialization parameters
        # @option params [Object] :subject The subject (typically a PVP entity)
        # @option params [Date] :effective_date The effective date for eligibility
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
