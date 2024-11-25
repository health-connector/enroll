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

      def download
        carrier_files = employer_event.render_payloads
        empty_files = carrier_files.select { |car| car.rendered_employers.empty? }

        return [:empty_files, failure_reason_message(empty_files)] if all_files_empty?(carrier_files, empty_files)

        zip_path = create_tempfile
        log_tempfile_path(zip_path)
        write_to_zip(carrier_files, zip_path)
        send_zip_file(zip_path)
      end

      private

      def all_files_empty?(carrier_files, empty_files)
        empty_files.size == carrier_files.size
      end

      def failure_reason_message(empty_files)
        unique_reasons = empty_files.map(&:render_reason).uniq
        reason_messages = unique_reasons.map { |reason| map_reason_to_message(reason) }
        "Reasons: #{reason_messages.join(', ')}"
      end

      def map_reason_to_message(reason)
        case reason
        when :event_not_whitelisted
          "Event not whitelisted"
        when :no_carrier_plan_years
          "No carrier plan years available"
        # Removed cases for invalid plan year, drop and has future plan year, and renewal and no future plan year
        else
          reason.to_s
        end
      end

      def create_tempfile
        z_file = Tempfile.new("employer_events_digest")
        zip_path = "#{z_file.path}.zip"
        z_file.close
        z_file.unlink
        zip_path
      end

      def log_tempfile_path(zip_path)
        Rails.logger.info "Temporary zip file created at path: #{zip_path}"
      end

      def write_to_zip(carrier_files, zip_path)
        ::Zip::File.open(zip_path, ::Zip::File::CREATE) do |zip|
          carrier_files.each do |car|
            car.write_to_zip(zip) unless car.rendered_employers.empty?
          end
        end
      end

      def send_zip_file(zip_path)
        [:success, zip_path]
      end
    end
  end
end
