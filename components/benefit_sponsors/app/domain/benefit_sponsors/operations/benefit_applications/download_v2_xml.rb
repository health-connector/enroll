# frozen_string_literal: true

module BenefitSponsors
  module Operations
    module BenefitApplications
      # This class handles the download of V2 XML for benefit applications
      class DownloadV2Xml
        include Dry::Monads[:result, :do]
        include L10nHelper

        # Benefit application states a V2 XML can be generated for. Renewing statuses in the admin table use these same states.
        ELIGIBLE_STATES = [:active, :termination_pending, :terminated, :expired].freeze

        def call(selected_event:, employer_application_id:, employer_actions_id:, benefit_sponsorship:)
          values = yield validate(selected_event, employer_application_id, employer_actions_id, benefit_sponsorship)
          application = yield fetch_application(values)
          yield validate_application_state(application)
          carrier_ids = yield fetch_carrier_ids(values[:selected_event], application)
          employer = yield fetch_employer(values)
          event_payload = yield generate_event_payload(employer, application)
          employer_event = yield create_employer_event(values[:selected_event], event_payload, values[:benefit_sponsorship], carrier_ids, application)
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

        # @param application [BenefitSponsors::BenefitApplications::BenefitApplication] selected plan year
        # @return [Dry::Monads::Result] Success with the application, or Failure when its state is not in ELIGIBLE_STATES
        def validate_application_state(application)
          return Success(application) if ELIGIBLE_STATES.include?(application.aasm_state)

          Failure(employer_application_id: [l10n("exchange.employer_applications.download_v2_xml.ineligible_state")])
        end

        def fetch_employer(values)
          Success(values[:benefit_sponsorship].profile)
        end

        # Renders the CV2 employer payload for the selected benefit application.
        #
        # @param employer [BenefitSponsors::Organizations::Profile] employer the payload describes
        # @param application [BenefitSponsors::BenefitApplications::BenefitApplication] application to include
        # @return [Dry::Monads::Result::Success] wraps the rendered xml
        # @note benefit_application_id must be a String. EventsHelper#employer_plan_years
        #   compares it with benefit_app.id.to_s, so a BSON::ObjectId never matches and the
        #   selected application is dropped from the payload unless it is eligible_for_export?
        def generate_event_payload(employer, application)
          payload = ApplicationController.render(
            template: "events/v2/employers/updated",
            formats: [:xml],
            locals: { employer: employer, manual_gen: false, benefit_application_id: application.id.to_s }
          )
          Success(payload)
        end

        # Finds the carriers that get a file for the selected event. For the carrier dropped event these
        # are the dropped carriers, for any other event the carriers on the selected plan year.
        #
        # @param event_name [String] selected V2 event
        # @param application [BenefitSponsors::BenefitApplications::BenefitApplication] selected plan year
        # @return [Dry::Monads::Result] Success with an Array of hbx_carrier_ids, or Failure when no carrier is found
        def fetch_carrier_ids(event_name, application)
          carrier_ids = application_carrier_ids(application)
          carrier_ids = yield dropped_carrier_ids(application, carrier_ids) if event_name == BenefitSponsors::EmployerEvents::EventNames::RENEWAL_CARRIER_CHANGE_EVENT
          return Failure(selected_event: [l10n("exchange.employer_applications.download_v2_xml.no_carriers")]) if carrier_ids.empty?

          Success(carrier_ids)
        end

        # Finds the carriers on the plan year being left that are not on its renewal. When the selected
        # plan year has a renewal that went out it is the plan year being left, otherwise it is the renewal.
        #
        # @param application [BenefitSponsors::BenefitApplications::BenefitApplication] selected plan year
        # @param carrier_ids [Array<Integer>] hbx_carrier_ids on the selected plan year
        # @return [Dry::Monads::Result] Success with the dropped hbx_carrier_ids, or Failure when there is no renewal or previous plan year
        def dropped_carrier_ids(application, carrier_ids)
          renewal = application.successors.detect(&:eligible_for_export?)
          return Success(carrier_ids - application_carrier_ids(renewal)) if renewal

          predecessor = application.predecessor
          return Failure(selected_event: [l10n("exchange.employer_applications.download_v2_xml.no_predecessor")]) if predecessor.blank?

          Success(application_carrier_ids(predecessor) - carrier_ids)
        end

        # @param application [BenefitSponsors::BenefitApplications::BenefitApplication] plan year to read
        # @return [Array<Integer>] hbx_carrier_ids of the products offered on the plan year
        def application_carrier_ids(application)
          products = application.benefit_packages.flat_map do |benefit_package|
            benefit_package.sponsored_benefits.flat_map { |sponsored_benefit| sponsored_benefit.products(benefit_package.start_on) }
          end
          products.map { |product| product.issuer_profile.hbx_carrier_id }.uniq
        end

        # Builds the employer event that renders one file per carrier, dated with the selected plan year.
        #
        # @param event_name [String] selected V2 event
        # @param event_payload [String] employer CV2 XML
        # @param benefit_sponsorship [BenefitSponsors::BenefitSponsorships::BenefitSponsorship] employer sponsorship
        # @param carrier_ids [Array<Integer>] hbx_carrier_ids that get a file
        # @param application [BenefitSponsors::BenefitApplications::BenefitApplication] selected plan year
        # @return [Dry::Monads::Result::Success] wraps a BenefitSponsors::Services::EmployerEvent
        def create_employer_event(event_name, event_payload, benefit_sponsorship, carrier_ids, application)
          employer_profile_hbx_id = benefit_sponsorship.hbx_id
          coverage_period = application.start_on.to_date..application.end_on.to_date
          Success(BenefitSponsors::Services::EmployerEvent.new(event_name, event_payload, employer_profile_hbx_id, carrier_ids: carrier_ids, coverage_period: coverage_period))
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
