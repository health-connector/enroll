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

    it 'passes the benefit application id to the xml template as a string' do
      expect(BenefitSponsors::ApplicationController).to receive(:render) do |args|
        expect(args[:locals][:benefit_application_id]).to be_a(String)
        expect(args[:locals][:benefit_application_id]).to eq(initial_application.id.to_s)
        "<organization></organization>"
      end
      subject.call(**params)
    end

    context 'when the selected benefit application is not eligible for export' do
      before do
        initial_application.update_attributes(aasm_state: :canceled)
      end

      it 'still passes the benefit application id to the xml template as a string' do
        expect(BenefitSponsors::ApplicationController).to receive(:render) do |args|
          expect(args[:locals][:benefit_application_id]).to eq(initial_application.id.to_s)
          "<organization></organization>"
        end
        subject.call(**params)
      end
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

  context 'end to end against real carrier rendering, no stubs', dbclean: :after_each do
    let(:params) do
      { selected_event: selected_event, employer_application_id: employer_application_id, employer_actions_id: employer_actions_id, benefit_sponsorship: benefit_sponsorship }
    end

    before do
      allow(benefit_sponsorship).to receive(:benefit_applications).and_return([initial_application])
      initial_application.update_attributes(aasm_state: :canceled)
      # real carriers are ExemptOrganization records, but the shared factory builds a plain
      # GeneralOrganization that the ExemptOrganization.issuer_profiles lookup in
      # EmployerEvent#render_payloads cannot find, and it sets neither of the two
      # carrier fields the renderer and the zip file name need
      issuer_profile.organization.update_attributes!(_type: "BenefitSponsors::Organizations::ExemptOrganization")
      issuer_profile.update_attributes!(hbx_carrier_id: 99_999, abbrev: "TEST")
    end

    it 'produces a real, non empty zip file containing the carrier plan year xml' do
      result = subject.call(**params)
      expect(result).to be_success

      zip_path = result.value!
      expect(File.exist?(zip_path)).to eq true
      expect(File.size(zip_path)).to be > 0

      entry_names = []
      xml_contents = []
      Zip::File.open(zip_path) do |zip|
        zip.each do |entry|
          entry_names << entry.name
          xml_contents << entry.get_input_stream.read
        end
      end

      expect(entry_names).not_to be_empty
      expect(xml_contents.join).to match(/<carrier>/)
      expect(xml_contents.join).to match(/<plan_year_start>/)
    end
  end
end
