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
end