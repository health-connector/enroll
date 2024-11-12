# frozen_string_literal: true

require 'nokogiri'

module BenefitSponsors
  module Services
    class V2XmlUploader
      include Acapi::Notifiers
      attr_reader :errors

      XSD_PATH = "#{Rails.root}/components/benefit_sponsors/cv/vocabulary.xsd".freeze

      def initialize(xml_file_path, expected_fein)
        @xml_string = File.read(xml_file_path)
        @expected_fein = expected_fein
        @errors = []
      end

      def upload
        doc = Nokogiri::XML(@xml_string)

        # Strip trailing spaces for all text nodes
        doc.traverse { |node| node.content = node.content.strip if node.text? }

        # Access the fein element with namespace and strip spaces
        fein = doc.at_xpath('//xmlns:fein', 'xmlns' => 'http://openhbx.org/api/terms/1.0')&.text&.strip

        # Verify the fein
        unless fein == @expected_fein
          @errors << "FEIN mismatch: expected #{@expected_fein}, found #{fein}"
          return [false, @errors]
        end

        xsd = Nokogiri::XML::Schema(File.open(XSD_PATH))
        @errors += xsd.validate(doc)
        return [false, @errors] unless @errors.blank?

        notify("acapi.info.events.trading_partner.employer_digest.published", { body: @xml_string })
        [true, @errors]
      end
    end
  end
end
