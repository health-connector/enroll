# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BenefitSponsors::Services::V2XmlUploader do
  describe "#upload" do
    # let(:xsd_path) { "#{Rails.root}/components/benefit_sponsors/cv/vocabulary.xsd" }
    let(:valid_xml_path) { "#{Rails.root}/spec/test_data/employer_digest/tufts_health_direct.xml" }
    let(:invalid_xml_path) { "#{Rails.root}/spec/test_data/employer_digest/DDA_20231026173711_20231026173711.xml" }

    context "when given valid XML" do
      it "uploads the XML successfully and notifies Acapi::Notifier" do
        uploader = described_class.new(valid_xml_path)

        result, errors = uploader.upload

        expect(result).to be true
        expect(errors.count).to eq 0
      end
    end

    context "when given invalid XML" do
      it "fails to upload and sets errors" do
        uploader = described_class.new(invalid_xml_path)

        result, errors = uploader.upload

        expect(result).to be false
        expect(errors.count).to eq 1
      end
    end

    context "when the XML file path is missing" do
      it "raises an error" do
        expect { described_class.new('non_existent_path.xml') }.to raise_error(Errno::ENOENT)
      end
    end
  end
end
