# frozen_string_literal: true

module BenefitMarkets
  module Operations
    module Pvp
      # Overrides top level evidence_configuration for feature specific configurations
      class PvpEvidenceConfiguration < ::Operations::Eligible::EvidenceConfiguration
        def key
          :shop_pvp_evidence
        end

        def title
          "Shop PVP Evidence"
        end
      end
    end
  end
end
