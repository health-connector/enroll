# frozen_string_literal: true

require 'set'

module BenefitSponsors
  module EmployerEvents
    class CarrierFile
      attr_accessor :carrier, :buffer, :begin_timestamp, :end_timestamp, :rendered_employers

      def initialize(carrier)
        @carrier = carrier
        @empty = true
        @buffer = StringIO.new
        @begin_timestamp = nil
        @end_timestamp = nil
        @rendered_employers = Set.new
      end

      def empty?
        @empty
      end

      def file_name
        return nil if @begin_timestamp.blank?
        return nil if @end_timestamp.blank?

        start_timestamp_string = @begin_timestamp.strftime("%Y%m%d%H%M%S")
        end_timestamp_string = @end_timestamp.strftime("%Y%m%d%H%M%S")
        "#{carrier.abbrev.upcase}_#{start_timestamp_string}_#{end_timestamp_string}.xml"
      end

      def render_event_using(renderer, event)
        if renderer.render_for(carrier, @buffer)
          @rendered_employers << event.employer_id
          @empty = false
          update_timestamps(renderer.timestamp)
        end
      rescue StandardError => e
        Rails.logger.error "[#{e.class.name}] #{e.message}"
      end

      def update_timestamps(timestamp)
        @begin_timestamp = [@begin_timestamp, timestamp].compact.min
        @end_timestamp = [@end_timestamp, timestamp].compact.max
      end

      def result
        return nil if @empty

        carrier_abbrev = carrier.abbrev.upcase
        header = <<-XMLHEADER
        <?xml version='1.0' encoding='UTF-8'?>
        <employer_digest_event
          xmlns="http://openhbx.org/api/terms/1.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://openhbx.org/api/terms/1.0 organization.xsd http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
          <event_name>urn:openhbx:events:v1:employer#digest_period_ended</event_name>
          <resource_instance_uri>
                  <id>urn:openhbx:resources:v1:carrier:abbreviation##{carrier_abbrev}</id>
          </resource_instance_uri>
          <body>
                  <employer_events>
                          <coverage_period>
                                  <begin_datetime>#{@begin_timestamp.iso8601}</begin_datetime>
                                  <end_datetime>#{@end_timestamp.iso8601}</end_datetime>
                          </coverage_period>
        XMLHEADER
        trailer = <<-XMLTRAILER
        </employer_events>
          </body>
        </employer_digest_event>
        XMLTRAILER
        @buffer << trailer
        header << @buffer.string
        [file_name, header]
      end

      def write_to_zip(zip)
        return if @empty

        f_name, data = result
        zip.get_output_stream(f_name) do |os|
          os.write(data)
        end
      end
    end
  end
end
