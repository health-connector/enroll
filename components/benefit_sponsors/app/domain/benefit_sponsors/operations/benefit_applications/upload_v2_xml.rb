# frozen_string_literal: true

module BenefitSponsors
  module Operations
    module BenefitApplications
      class UploadV2Xml
        include L10nHelper
        include Dry::Monads[:result, :do]

        def call(file:, employer_actions_id:, benefit_sponsorship:)
          values = yield validate(file, employer_actions_id, benefit_sponsorship)
          upload_result = yield upload_xml(values)

          Success(upload_result)
        end

        private

        def validate(file, employer_actions_id, benefit_sponsorship)
          contract = BenefitSponsors::Validators::BenefitApplications::UploadV2XmlContract.new
          result = contract.call(
            file: file,
            employer_actions_id: employer_actions_id,
            benefit_sponsorship: benefit_sponsorship
          )
          result.success? ? Success(result.to_h) : Failure(result.errors.to_h)
        end

        def upload_xml(values)
          fein = values[:benefit_sponsorship].fein
          xml_file_path = values[:file].tempfile.path
          v2_xml_uploader = ::BenefitSponsors::Services::V2XmlUploader.new(xml_file_path, fein)
          result, errors = v2_xml_uploader.upload

          if result
            Success(l10n('exchange.employer_applications.upload_v2_xml.success_message', fein: fein))
          else
            error_messages = errors.map { |e| "Error: #{e}" }.join(", ")
            Failure(l10n('exchange.employer_applications.upload_v2_xml.failure_message', errors: error_messages))
          end
        end
      end
    end
  end
end
