# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BenefitSponsors::Services::V2XmlUploader do
  describe "#upload" do
    let(:valid_xml_path) { "#{Rails.root}/spec/test_data/employer_digest/tufts_health_direct.xml" }
    let(:invalid_xml_path) { "#{Rails.root}/spec/test_data/employer_digest/DDA_20231026173711_20231026173711.xml" }
    let(:expected_fein) { "123456789" }

    context "when given valid XML with matching FEIN" do
      it "uploads the XML successfully and notifies Acapi::Notifier" do
        uploader = described_class.new(valid_xml_path, expected_fein)
        expect(uploader).to receive(:notify).with("acapi.info.events.trading_partner.employer_digest.published", { body: anything, enable_customized_v1: true })

        result, errors = uploader.upload

        expect(result).to be true
        expect(errors).to be_empty
      end
    end

    context "when given XML with mismatching FEIN" do
      it "fails to upload and sets FEIN mismatch error" do
        uploader = described_class.new(invalid_xml_path, expected_fein)

        result, errors = uploader.upload

        expect(result).to be false
        expect(errors).to include("FEIN mismatch: expected 123456789, found 010101010")
      end
    end

    context "when given invalid XML" do
      it "fails to upload and sets XSD validation errors" do
        allow_any_instance_of(Nokogiri::XML::Schema).to receive(:validate).and_return([Nokogiri::XML::SyntaxError.new("XSD validation error")])
        uploader = described_class.new(valid_xml_path, expected_fein)

        result, errors = uploader.upload

        expect(result).to be false
        expect(errors.first).to be_a(Nokogiri::XML::SyntaxError)
        expect(errors.first.message).to eq("XSD validation error")
      end
    end

    context "when the XML file path is missing" do
      it "raises an error" do
        expect { described_class.new('non_existent_path.xml', expected_fein) }.to raise_error(Errno::ENOENT)
      end
    end
  end
end
