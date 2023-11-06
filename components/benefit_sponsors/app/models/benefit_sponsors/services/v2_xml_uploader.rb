# frozen_string_literal: true

require 'nokogiri'

module BenefitSponsors
  module Services
    class V2XmlUploader
      include Acapi::Notifiers

      attr_reader :errors

      XSD_PATH = "#{Rails.root}/components/benefit_sponsors/cv/vocabulary.xsd"

      def initialize(xml_file_path)
        @xml_string = File.read(xml_file_path)
      end

      def upload
        doc = Nokogiri::XML(@xml_string)
        xsd = Nokogiri::XML::Schema(File.open(XSD_PATH))
        @errors = xsd.validate(doc)
        return [false, @errors] unless @errors.blank?

        notify("acapi.info.events.trading_partner.employer_digest.published", { :body => @xml_string })
        [true, @errors]
      end
    end
  end
end
