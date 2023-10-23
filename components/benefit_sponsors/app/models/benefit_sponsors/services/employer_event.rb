# frozen_string_literal: true

require 'zip'

module BenefitSponsors
  module Services
    class EmployerEvent
      include Mongoid::Document
      include Mongoid::Timestamps

      attr_accessor :event_time, :event_name, :resource_body, :employer_id

      def initialize(event_name, resource_body, employer_id)
        @event_time = Time.now
        @event_name = event_name
        @resource_body = resource_body
        @employer_id = employer_id
      end

      def render_payloads
        issuer_profiles = BenefitSponsors::Organizations::ExemptOrganization.issuer_profiles
        carrier_files = issuer_profiles.map(&:profiles).flatten.map do |car|
          BenefitSponsors::EmployerEvents::CarrierFile.new(car)
        end
        event_renderer = EmployerEvents::Renderer.new(self)
        carrier_files.each do |car|
          car.render_event_using(event_renderer, self)
        end
        carrier_files
      end
    end
  end
end
