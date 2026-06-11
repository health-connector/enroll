# frozen_string_literal: true

require 'zip'

module BenefitSponsors
  module Services
    class EmployerEvent

      attr_accessor :event_time, :event_name, :resource_body, :employer_profile_id

      def initialize(event_name, resource_body, employer_profile_id)
        @event_time = Time.now
        @event_name = event_name
        @resource_body = resource_body
        # employer_profile_id is a benefit_sponsorship.hbx_id
        @employer_profile_id = employer_profile_id
      end

      def render_payloads
        issuer_profiles = BenefitSponsors::Organizations::ExemptOrganization.issuer_profiles || []

        carrier_files = issuer_profiles.flat_map(&:issuer_profile).compact.map do |car|
          BenefitSponsors::EmployerEvents::CarrierFile.new(car)
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

      def log_info(message)
        Rails.logger.tagged(self.class.name) { Rails.logger.info(message) }
      end
    end
  end
end
