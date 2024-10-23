# frozen_string_literal: true

module BenefitMarkets
  module PvpEligibilities
    class PvpEligibility < ::Eligible::Eligibility
      evidence :pvp_evidence, class_name: "BenefitMarkets::PvpEligibilities::AdminAttestedEvidence"

      grant :pvp_grant, class_name: "BenefitMarkets::PvpEligibilities::PvpGrant"
    end
  end
end
