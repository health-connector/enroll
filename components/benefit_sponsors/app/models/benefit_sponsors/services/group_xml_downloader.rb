# frozen_string_literal: true

require 'zip'
require 'tempfile'

module BenefitSponsors
  module Services
    class GroupXmlDownloader
      attr_accessor :employer_event

      def initialize(employer_event)
        @employer_event = employer_event
      end

      def download(controller)
        carrier_files = employer_event.render_payloads
        z_file = Tempfile.new("employer_events_digest")
        zip_path = z_file.path + ".zip"
        z_file.close
        z_file.unlink
        ::Zip::File.open(zip_path, ::Zip::File::CREATE) do |zip|
          carrier_files.each do |car|
            car.write_to_zip(zip)
          end
        end
        controller.send_file(zip_path)
      end
    end
  end
end
