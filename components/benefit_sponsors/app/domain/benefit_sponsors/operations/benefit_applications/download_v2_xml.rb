# frozen_string_literal: true

module BenefitSponsors
  module Operations
    module BenefitApplications
      # This class handles the download of V2 XML for benefit applications
      class DownloadV2Xml
        include Dry::Monads[:result, :do]

        def call(selected_event:, employer_application_id:, employer_actions_id:, benefit_sponsorship:)
          values = yield validate(selected_event, employer_application_id, employer_actions_id, benefit_sponsorship)
          application = yield fetch_application(values)
          employer = yield fetch_employer(values)
          event_payload = yield generate_event_payload(employer, application)
          employer_event = yield create_employer_event(values[:selected_event], event_payload, values[:benefit_sponsorship])
          download_result = yield download_group_xml(employer_event)

          Success(download_result)
        end

        private

        def validate(selected_event, employer_application_id, employer_actions_id, benefit_sponsorship)
          contract = BenefitSponsors::Validators::BenefitApplications::DownloadV2XmlContract.new
          result = contract.call(
            selected_event: selected_event,
            employer_application_id: employer_application_id,
            employer_actions_id: employer_actions_id,
            benefit_sponsorship: benefit_sponsorship
          )
          result.success? ? Success(result.to_h) : Failure(result.errors.to_h)
        end

        def fetch_application(values)
          application = values[:benefit_sponsorship].benefit_applications.detect { |app| app.id.to_s == values[:employer_application_id] }
          application ? Success(application) : Failure("Application not found")
        end

        def fetch_employer(values)
          Success(values[:benefit_sponsorship].profile)
        end

        def generate_event_payload(employer, application)
          payload = ApplicationController.render(
            template: "events/v2/employers/updated",
            formats: [:xml],
            locals: { employer: employer, manual_gen: false, benefit_application_id: application.id }
          )
          Success(payload)
        end

        def create_employer_event(event_name, event_payload, benefit_sponsorship)
          employer_profile_hbx_id = benefit_sponsorship.hbx_id
          Success(BenefitSponsors::Services::EmployerEvent.new(event_name, event_payload, employer_profile_hbx_id))
        end

        def download_group_xml(employer_event)
          group_xml_downloader = BenefitSponsors::Services::GroupXmlDownloader.new(employer_event)
          download_status = group_xml_downloader.download

          if download_status[0] == :empty_files
            Failure([:empty_files, download_status[1]]) # download_status[1] is a failure message
          elsif download_status[0] == :success
            Success(download_status[1]) # download_status[1] is a file path
          end
        end
      end
    end
  end
end
