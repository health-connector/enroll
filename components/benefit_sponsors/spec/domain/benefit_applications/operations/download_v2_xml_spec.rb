# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe BenefitSponsors::Operations::BenefitApplications::DownloadV2Xml, dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"
  include_context "setup employees"

  let(:selected_event) { 'benefit_coverage_initial_application_eligible' }
  let(:employer_application_id) { initial_application.id.to_s }
  let(:employer_actions_id) { '123456' }

  context 'with invalid params' do
    context 'missing selected_event' do
      let(:params) do
        { selected_event: nil, employer_application_id: employer_application_id, employer_actions_id: employer_actions_id, benefit_sponsorship: benefit_sponsorship }
      end

      it 'returns failure' do
        result = subject.call(**params)
        expect(result).to be_failure
        expect(result.failure).to include(selected_event: ["must be filled"])
      end
    end

    context 'missing employer_application_id' do
      let(:params) do
        { selected_event: selected_event, employer_application_id: nil, employer_actions_id: employer_actions_id, benefit_sponsorship: benefit_sponsorship }
      end

      it 'returns failure' do
        result = subject.call(**params)
        expect(result).to be_failure
        expect(result.failure).to include(employer_application_id: ["must be filled"])
      end
    end

    context 'missing employer_actions_id' do
      let(:params) do
        { selected_event: selected_event, employer_application_id: employer_application_id, employer_actions_id: nil, benefit_sponsorship: benefit_sponsorship }
      end

      it 'returns failure' do
        result = subject.call(**params)
        expect(result).to be_failure
        expect(result.failure).to include(employer_actions_id: ["must be filled"])
      end
    end

    context 'missing benefit_sponsorship' do
      let(:params) do
        { selected_event: selected_event, employer_application_id: employer_application_id, employer_actions_id: employer_actions_id, benefit_sponsorship: nil }
      end

      it 'returns failure' do
        result = subject.call(**params)
        expect(result).to be_failure
        expect(result.failure).to include(benefit_sponsorship: ["must be filled"])
      end
    end

    context 'invalid benefit_sponsorship object' do
      let(:invalid_benefit_sponsorship) { double("InvalidSponsorship") }
      let(:params) do
        { selected_event: selected_event, employer_application_id: employer_application_id, employer_actions_id: employer_actions_id, benefit_sponsorship: invalid_benefit_sponsorship }
      end

      it 'returns failure' do
        result = subject.call(**params)
        expect(result).to be_failure
        expect(result.failure[:benefit_sponsorship]).to include("must respond to benefit_applications")
      end
    end
  end

  context 'with valid params' do
    let(:params) do
      { selected_event: selected_event, employer_application_id: employer_application_id, employer_actions_id: employer_actions_id, benefit_sponsorship: benefit_sponsorship }
    end

    before do
      allow_any_instance_of(BenefitSponsors::Services::GroupXmlDownloader).to receive(:download).and_return([:success, 'file_path'])
      allow(benefit_sponsorship).to receive(:benefit_applications).and_return([initial_application])
    end

    it 'should download V2 XML successfully' do
      result = subject.call(**params)
      expect(result).to be_success
      expect(result.value!).to eq('file_path')
    end

    context 'when group XML download fails with empty files' do
      before do
        allow_any_instance_of(BenefitSponsors::Services::GroupXmlDownloader).to receive(:download).and_return([:empty_files, "No files found"])
      end

      it 'returns failure with empty files error' do
        result = subject.call(**params)
        expect(result).to be_failure
        expect(result.failure).to eq([:empty_files, "No files found"])
      end
    end
  end
end
