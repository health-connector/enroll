# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"
require Rails.root.join("lib/v2_group_xml_generator")

RSpec.describe V2GroupXmlGenerator, dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  it 'renders consecutive runs in the same process' do
    Dir.mktmpdir do |directory|
      Dir.chdir(directory) do
        2.times do
          generator = described_class.new(
            [abc_organization.fein],
            initial_application.start_on.strftime("%Y%m%d"),
            initial_application.end_on.strftime("%Y%m%d")
          )
          expect(generator).to receive(:write).once.and_call_original

          generator.generate_xmls
        end
      end
    end
  end

  it 'passes the selected application to the dropped-carrier renderer' do
    Dir.mktmpdir do |directory|
      Dir.chdir(directory) do
        generator = described_class.new([abc_organization.fein], '20250901', '20260831')
        current_carrier = double(legal_name: 'Current Carrier')
        dropped_carrier = double(legal_name: 'Dropped Carrier')
        xml = '<organization><id><id>employer</id></id></organization>'
        event = 'urn:openhbx:events:v1:employer#benefit_coverage_renewal_carrier_dropped'
        renderer_calls = []
        written_names = []

        allow(generator).to receive(:find_benefit_application).and_return(initial_application)
        allow(generator).to receive(:benefit_application_carriers).with(initial_application).and_return([current_carrier])
        allow(generator).to receive(:switched_carriers).with(benefit_sponsorship.profile, initial_application).and_return([dropped_carrier])
        allow(generator).to receive(:remove_other_carrier_nodes) do |*arguments|
          renderer_calls << arguments
          [arguments[4].present? ? event : 'other_event', 'employer', xml]
        end
        allow(ApplicationController).to receive(:render).and_return(xml)
        allow(generator).to receive(:write) { |_payload, name| written_names << name }

        generator.generate_xmls

        dropped_carrier_call = renderer_calls.find { |arguments| arguments[1] == 'Dropped Carrier' }
        expect(dropped_carrier_call&.at(3)).to eq(initial_application)
        expect(dropped_carrier_call&.at(4)).to include(event: event)
        expect(written_names).to include('Dropped Carrier')
      end
    end
  end

  context 'when a carrier is dropped at renewal' do
    let(:aasm_state) { :expired }
    let(:renewal_effective_period) { renewal_effective_date..renewal_effective_date.next_year.prev_day }
    let!(:renewal_application) do
      create(
        :benefit_sponsors_benefit_application,
        :with_benefit_sponsor_catalog,
        :with_benefit_package,
        passed_benefit_sponsor_catalog: benefit_sponsorship.benefit_sponsor_catalog_for(renewal_effective_date),
        benefit_sponsorship: benefit_sponsorship,
        predecessor_id: initial_application.id,
        aasm_state: :active,
        open_enrollment_period: open_enrollment_period.min.next_year..open_enrollment_period.max.next_year,
        recorded_rating_area: renewal_rating_area,
        recorded_service_areas: benefit_sponsorship.service_areas_on(renewal_effective_date),
        package_kind: :metal_level,
        benefit_application_items: [build(:benefit_sponsors_benefit_application_item, effective_period: renewal_effective_period, state: :active)]
      )
    end
    let(:renewal_carrier) { create(:benefit_sponsors_organizations_issuer_profile, assigned_site: site) }
    let(:dropped_event) { 'urn:openhbx:events:v1:employer#benefit_coverage_renewal_carrier_dropped' }
    let(:namespace) { { 'cv' => 'http://openhbx.org/api/terms/1.0' } }

    before do
      renewal_carrier.organization.update_attributes!(legal_name: 'Renewal Carrier')
      renewal_catalog = renewal_application.benefit_sponsor_catalog
      renewal_catalog.class.collection.update_one({ _id: renewal_catalog.id }, { '$set' => { 'product_packages.$[].products.$[].issuer_profile_id' => renewal_carrier.id } })
    end

    def generate_for(application)
      Dir.mktmpdir do |directory|
        Dir.chdir(directory) do
          described_class.new([abc_organization.fein], application.start_on.strftime("%Y%m%d"), application.end_on.strftime("%Y%m%d")).generate_xmls
          Dir.glob("employer_xmls.v2/*.xml").to_h { |path| [File.basename(path, ".xml"), Nokogiri::XML(File.read(path))] }
        end
      end
    end

    def event_names(document)
      document.xpath('//cv:employer_event/cv:event_name', namespace).map(&:text)
    end

    def plan_year_starts(document)
      document.xpath('//cv:plan_year/cv:plan_year_start', namespace).map(&:text)
    end

    it 'writes only the carrier dropped event for the dropped carrier when the prior plan year is given' do
      files = generate_for(initial_application)

      expect(files.keys).to eq([issuer_profile.legal_name])
      expect(event_names(files[issuer_profile.legal_name])).to eq([dropped_event])
      expect(plan_year_starts(files[issuer_profile.legal_name])).to eq([initial_application.start_on.strftime("%Y%m%d")])
    end

    it 'writes the carrier dropped event for the dropped carrier when the renewal plan year is given' do
      files = generate_for(renewal_application)

      expect(files.keys).to match_array([issuer_profile.legal_name, renewal_carrier.legal_name])
      expect(event_names(files[issuer_profile.legal_name])).to eq([dropped_event])
      expect(plan_year_starts(files[issuer_profile.legal_name])).to eq([initial_application.start_on.strftime("%Y%m%d")])
      expect(event_names(files[renewal_carrier.legal_name])).not_to include(dropped_event)
    end
  end
end
