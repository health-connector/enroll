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
        empty_files = carrier_files.select { |car| car.instance_variable_get(:@rendered_employers).empty? }

        return :empty_files if empty_files.size == carrier_files.size

        z_file = Tempfile.new("employer_events_digest")
        zip_path = "#{z_file.path}.zip"
        Rails.logger.info "Temporary zip file created at path: #{zip_path}"
        z_file.close
        z_file.unlink

        ::Zip::File.open(zip_path, ::Zip::File::CREATE) do |zip|
          carrier_files.each do |car|
            car.write_to_zip(zip) unless car.instance_variable_get(:@rendered_employers).empty?
          end
        end

        controller.send_file(zip_path)
        :success
      end
    end
  end
end
