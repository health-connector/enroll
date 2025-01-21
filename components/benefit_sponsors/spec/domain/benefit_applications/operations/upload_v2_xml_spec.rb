# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe BenefitSponsors::Operations::BenefitApplications::UploadV2Xml, dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  let(:filename) { "#{Rails.root}/spec/test_data/employer_digest/tufts_health_direct.xml" }
  let(:uploaded_file) { fixture_file_upload(filename, 'application/xml') }
  let(:employer_actions_id) { "employer_actions_123455" }

  context 'with valid params' do
    let(:params) do
      {
        file: uploaded_file,
        employer_actions_id: employer_actions_id,
        benefit_sponsorship: benefit_sponsorship
      }
    end

    context 'successful upload' do
      before do
        allow_any_instance_of(BenefitSponsors::Services::V2XmlUploader).to receive(:upload).and_return([true, []])
      end

      it 'returns success with correct message' do
        result = subject.call(**params)
        expect(result).to be_success
        expect(result.value!).to eq("Successfully uploaded V2 digest XML for employer FEIN: #{benefit_sponsorship.fein}.")
      end
    end

    context 'failed upload' do
      before do
        allow_any_instance_of(BenefitSponsors::Services::V2XmlUploader).to receive(:upload).and_return([false, ['FEIN mismatch']])
      end

      it 'returns failure with error message' do
        result = subject.call(**params)
        expect(result).to be_failure
        expect(result.failure).to eq('Failed to upload XML. Error: FEIN mismatch')
      end
    end
  end

  context 'with invalid params' do
    context 'missing file' do
      let(:params) do
        {
          employer_actions_id: employer_actions_id,
          benefit_sponsorship: benefit_sponsorship
        }
      end

      it 'returns failure' do
        expect { subject.call(**params) }.to raise_error(ArgumentError)
      end
    end

    context 'invalid file type' do
      let(:invalid_file) { fixture_file_upload("#{Rails.root}/spec/test_data/sample.txt", 'text/plain') }
      let(:params) do
        {
          file: invalid_file,
          employer_actions_id: employer_actions_id,
          benefit_sponsorship: benefit_sponsorship
        }
      end

      it 'returns failure' do
        result = subject.call(**params)
        expect(result).to be_failure
        expect(result.failure).to include(file: ['must be an XML file'])
      end
    end
  end
end
