# frozen_string_literal: true

module BenefitSponsors
  module Validators
    module BenefitApplications
      # Contract for validating input parameters for upload V2 XML
      class UploadV2XmlContract < Dry::Validation::Contract
        params do
          required(:file).filled
          required(:employer_actions_id).filled(:string)
          required(:benefit_sponsorship).filled
        end

        rule(:file) do
          # First, validate file upload object
          unless value.is_a?(ActionDispatch::Http::UploadedFile) || 
                 value.is_a?(Rack::Test::UploadedFile) && 
                 value.tempfile.present? && 
                 File.exist?(value.tempfile.path)
            key.failure('must be a valid uploaded file')
            next
          end

          # If first validation passes, check file extension
          unless File.extname(value.original_filename).downcase == '.xml'
            key.failure('must be an XML file')
          end
        end

        rule(:benefit_sponsorship) do
          key.failure('must respond to fein') unless value.respond_to?(:fein)
        end
      end
    end
  end
end
