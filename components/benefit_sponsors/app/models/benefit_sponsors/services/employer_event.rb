# frozen_string_literal: true

require 'zip'

module BenefitSponsors
  module Services
    class EmployerEvent

      attr_accessor :event_time, :event_name, :resource_body, :employer_profile_id, :carrier_ids, :coverage_period

      # @param event_name [String] V2 event name
      # @param resource_body [String] employer CV2 XML
      # @param employer_profile_id [String] benefit sponsorship hbx_id
      # @param carrier_ids [Array<Integer>, nil] hbx_carrier_ids to render files for, nil renders every carrier
      # @param coverage_period [Range<Date>, nil] plan year dates written to each carrier file
      def initialize(event_name, resource_body, employer_profile_id, carrier_ids: nil, coverage_period: nil)
        @event_time = Time.current
        @event_name = event_name
        @resource_body = resource_body
        # employer_profile_id is a benefit_sponsorship.hbx_id
        @employer_profile_id = employer_profile_id
        @carrier_ids = carrier_ids
        @coverage_period = coverage_period
      end

      def render_payloads
        carrier_files = carriers_to_render.map do |car|
          BenefitSponsors::EmployerEvents::CarrierFile.new(car, coverage_period: coverage_period)
        end

        event_renderer = BenefitSponsors::EmployerEvents::Renderer.new(self)
        log_info("Initialized event renderer")

        carrier_files.each do |car|
          log_info("Rendering event using CarrierFile: #{car&.carrier&.id}")
          car.render_event_using(event_renderer, self)
        end

        log_info("Finished rendering payloads")

        carrier_files
      end

      private

      # @return [Array<BenefitSponsors::Organizations::IssuerProfile>] carriers in carrier_ids, or every carrier when carrier_ids is nil
      def carriers_to_render
        carriers = (BenefitSponsors::Organizations::ExemptOrganization.issuer_profiles || []).flat_map(&:issuer_profile).compact
        return carriers if carrier_ids.nil?

        carriers.select { |car| carrier_ids.include?(car.hbx_carrier_id) }
      end

      def log_info(message)
        Rails.logger.tagged(self.class.name) { Rails.logger.info(message) }
      end
    end
  end
end
