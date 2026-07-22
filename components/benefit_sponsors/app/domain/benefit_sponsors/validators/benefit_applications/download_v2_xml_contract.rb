# frozen_string_literal: true

module BenefitSponsors
  module Validators
    module BenefitApplications
      # Contract for validating input parameters for downloading V2 XML
      class DownloadV2XmlContract < Dry::Validation::Contract

        params do
          required(:selected_event).filled(:string)
          required(:employer_application_id).filled(:string)
          required(:employer_actions_id).filled(:string)
          required(:benefit_sponsorship).filled
        end

        rule(:benefit_sponsorship) do
          key.failure('must respond to benefit_applications') unless value.respond_to?(:benefit_applications)
          key.failure('must respond to hbx_id') unless value.respond_to?(:hbx_id)
          key.failure('must respond to profile') unless value.respond_to?(:profile)
        end
      end
    end
  end
end
