# frozen_string_literal: true

require 'zip'

module BenefitSponsors
  module EmployerEvents
    class CarrierFile
      attr_accessor :carrier, :buffer, :begin_timestamp, :end_timestamp, :rendered_employers, :render_reason, :coverage_period

      # @param coverage_period [Range<Date>, nil] plan year dates for the digest, nil falls back to the event timestamps
      def initialize(carrier, coverage_period: nil)
        @carrier = carrier
        @coverage_period = coverage_period
        @empty = true
        @buffer = StringIO.new
        @begin_timestamp = nil
        @end_timestamp = nil
        @rendered_employers = Set.new
        @render_reason = nil
      end

      def empty?
        @empty
      end

      # matches the file names written by lib/v2_group_xml_generator.rb
      def file_name
        "#{carrier.legal_name.tr('/\\', '-')}.xml"
      end

      def render_event_using(renderer, event)
        result = renderer.render_for(carrier, @buffer)
        if result == true
          employer_profile = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(hbx_id: event.employer_profile_id).first
          @rendered_employers << employer_profile.organization.hbx_id
          @empty = false
          update_timestamps(renderer.timestamp)
          @render_reason = :success
        else
          @render_reason = result
        end
      rescue StandardError => e
        log_error("failed to render carrier file for carrier #{carrier&.id}: #{e.message}")
        # a symbol rather than e.message because render_reason is surfaced to the browser
        @render_reason = :render_error
      end

      def update_timestamps(timestamp)
        @begin_timestamp = [@begin_timestamp, timestamp].compact.min
        @end_timestamp = [@end_timestamp, timestamp].compact.max
      end

      def result
        return nil if @empty

        carrier_abbrev = carrier.abbrev.upcase
        begin_datetime = coverage_period ? coverage_period.begin.strftime("%Y-%m-%dT00:00:00") : @begin_timestamp.iso8601
        end_datetime = coverage_period ? coverage_period.end.strftime("%Y-%m-%dT00:00:00") : @end_timestamp.iso8601
        # layout mirrors events/v2/employers/group_xml.haml used by lib/v2_group_xml_generator.rb
        header = <<~XMLHEADER
          <?xml version='1.0' encoding='utf-8' ?>
          <employer_digest_event xmlns='http://openhbx.org/api/terms/1.0' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation='http://openhbx.org/api/terms/1.0 organization.xsd http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd'>
          <event_name>urn:openhbx:events:v1:employer#digest_period_ended</event_name>
          <resource_instance_uri>
          <id>urn:openhbx:resources:v1:carrier:abbreviation##{carrier_abbrev}</id>
          </resource_instance_uri>
          <body>
          <employer_events>
          <coverage_period>
          <begin_datetime>#{begin_datetime}</begin_datetime>
          <end_datetime>#{end_datetime}</end_datetime>
          </coverage_period>
        XMLHEADER
        trailer = <<~XMLTRAILER
          </employer_events>
          </body>
          </employer_digest_event>
        XMLTRAILER
        @buffer << trailer
        header += @buffer.string
        [file_name, header]
      end

      def write_to_zip(zip)
        return if @empty

        f_name, data = result
        zip.get_output_stream(f_name) do |os|
          os.write(data)
        end
      end

      private

      def log_error(message)
        Rails.logger.tagged(self.class.name) { Rails.logger.error(message) }
      end
    end
  end
end
