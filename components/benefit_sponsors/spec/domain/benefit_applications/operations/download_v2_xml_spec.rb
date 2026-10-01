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

    context 'when the selected benefit application is canceled' do
      before do
        initial_application.update_attributes(aasm_state: :canceled)
      end

      it 'returns failure without rendering the payload' do
        expect(BenefitSponsors::ApplicationController).not_to receive(:render)

        result = subject.call(**params)

        expect(result).to be_failure
        expect(result.failure[:employer_application_id].first).to match(/active, termination pending, terminated or expired/)
      end
    end

    [:termination_pending, :terminated, :expired].each do |state|
      context "when the selected benefit application is #{state}" do
        before do
          initial_application.update_attributes(aasm_state: state)
        end

        it 'downloads successfully' do
          expect(subject.call(**params)).to be_success
        end
      end
    end

    [:enrollment_open, :enrollment_eligible, :retroactive_canceled, :suspended, :reinstated].each do |state|
      context "when the selected benefit application is #{state}" do
        before do
          initial_application.update_attributes(aasm_state: state)
        end

        it 'returns failure' do
          expect(subject.call(**params)).to be_failure
        end
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

    it 'lays out the employer xml like the manual group xml script' do
      xml = ""
      Zip::File.open(subject.call(**params).value!) { |zip| xml = zip.first.get_input_stream.read }

      expect(xml).to start_with("<?xml version='1.0' encoding='utf-8' ?>\n<employer_digest_event xmlns='http://openhbx.org/api/terms/1.0'")
      expect(xml).to match(/^<body>\n<organization /)
      expect(xml).to end_with("</organization>\n\n</body>\n</employer_event>\n</employer_events>\n</body>\n</employer_digest_event>\n")
    end

    it 'only renders files for carriers on the selected application' do
      other_carrier = create(:benefit_sponsors_organizations_issuer_profile, hbx_carrier_id: 88_888, abbrev: "OTHER")
      other_carrier.organization.update_attributes!(_type: "BenefitSponsors::Organizations::ExemptOrganization")

      expect(BenefitSponsors::EmployerEvents::CarrierFile).to receive(:new).with(issuer_profile, anything).once.and_call_original
      expect(BenefitSponsors::EmployerEvents::CarrierFile).not_to receive(:new).with(other_carrier, anything)

      expect(subject.call(**params)).to be_success
    end

    it 'writes the selected plan year dates as the coverage period' do
      xml = ""
      Zip::File.open(subject.call(**params).value!) { |zip| xml = zip.first.get_input_stream.read }

      expect(xml).to include("<begin_datetime>#{initial_application.start_on.to_date}T00:00:00</begin_datetime>")
      expect(xml).to include("<end_datetime>#{initial_application.end_on.to_date}T00:00:00</end_datetime>")
    end
  end

  describe '#fetch_carrier_ids' do
    let(:application_carrier_ids) do
      products = initial_application.benefit_packages.flat_map(&:sponsored_benefits).flat_map { |sponsored_benefit| sponsored_benefit.products(initial_application.start_on) }
      products.map { |product| product.issuer_profile.hbx_carrier_id }.uniq
    end

    it 'returns only the carriers offered on the selected application' do
      result = subject.send(:fetch_carrier_ids, 'benefit_coverage_initial_application_eligible', initial_application)

      expect(result).to be_success
      expect(result.value!).to match_array(application_carrier_ids)
    end

    it 'fails a carrier drop when the application has no predecessor' do
      result = subject.send(:fetch_carrier_ids, 'benefit_coverage_renewal_carrier_dropped', initial_application)

      expect(result).to be_failure
      expect(result.failure[:selected_event].first).to match(/No previous plan year/)
    end

    context 'with a predecessor application' do
      let(:predecessor) { instance_double(BenefitSponsors::BenefitApplications::BenefitApplication) }

      before do
        allow(initial_application).to receive(:predecessor).and_return(predecessor)
        allow(subject).to receive(:application_carrier_ids).with(initial_application).and_return([20_001])
      end

      it 'returns only the carriers dropped since the predecessor for a carrier drop' do
        allow(subject).to receive(:application_carrier_ids).with(predecessor).and_return([20_001, 20_004])

        result = subject.send(:fetch_carrier_ids, 'benefit_coverage_renewal_carrier_dropped', initial_application)

        expect(result.value!).to eq([20_004])
      end

      it 'fails a carrier drop when no carrier was dropped' do
        allow(subject).to receive(:application_carrier_ids).with(predecessor).and_return([20_001])

        result = subject.send(:fetch_carrier_ids, 'benefit_coverage_renewal_carrier_dropped', initial_application)

        expect(result.failure[:selected_event].first).to match(/No carriers found/)
      end
    end
  end

  describe '#create_employer_event' do
    it 'passes the carrier ids and plan year dates to the employer event' do
      result = subject.send(:create_employer_event, 'benefit_coverage_initial_application_eligible', '<organization/>', benefit_sponsorship, [20_011], initial_application)

      expect(result.value!.carrier_ids).to eq([20_011])
      expect(result.value!.coverage_period).to eq(initial_application.start_on.to_date..initial_application.end_on.to_date)
    end
  end
end
