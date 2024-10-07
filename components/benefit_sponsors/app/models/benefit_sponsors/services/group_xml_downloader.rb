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

        a_time = Time.now
        today_date_time = TimeKeeper.local_time(a_time).strftime("%Y%m%d_%H%M%S")
        zip_file_name = "employer_events_digest_#{today_date_time}.zip"
        zip_path = Rails.root.join('tmp', zip_file_name)
        Rails.logger.info "Temporary zip file created at path: #{zip_path}"

        ::Zip::File.open(zip_path, ::Zip::File::CREATE) do |zip|
          carrier_files.each do |car|
            car.write_to_zip(zip) unless car.instance_variable_get(:@rendered_employers).empty?
          end
        end

        controller.send_file(zip_path, filename: zip_file_name, type: 'application/zip', disposition: 'attachment')
        File.delete(zip_path)
        :success
      end
    end
  end
end
