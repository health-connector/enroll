# frozen_string_literal: true

require 'rails_helper'
require 'zip'

RSpec.describe BenefitSponsors::Services::GroupXmlDownloader, type: :service do
  let(:employer_event) { double('EmployerEvent') }
  let(:controller) { double('Controller') }
  let(:carrier_file) { double('CarrierFile') }
  let(:empty_carrier_file) { double('EmptyCarrierFile') }
  let(:zip_file) { Tempfile.new(['employer_events_digest', '.zip']) }
  let(:zip_path) { zip_file.path }

  subject { described_class.new(employer_event) }

  before do
    allow(employer_event).to receive(:render_payloads).and_return([carrier_file, empty_carrier_file])
    allow(carrier_file).to receive(:instance_variable_get).with(:@rendered_employers).and_return(['employer1'])
    allow(empty_carrier_file).to receive(:instance_variable_get).with(:@rendered_employers).and_return([])
    allow(TimeKeeper).to receive(:local_time).and_return(Time.now)
    allow(Rails.root).to receive(:join).and_return(zip_path)
    allow(Rails.logger).to receive(:info)
    allow(controller).to receive(:send_file)
    allow(File).to receive(:delete)
  end

  describe '#initialize' do
    it 'initializes with an employer_event' do
      expect(subject.employer_event).to eq(employer_event)
    end
  end

  describe '#download' do
    context 'when all carrier files are empty' do
      before do
        allow(employer_event).to receive(:render_payloads).and_return([empty_carrier_file])
      end

      it 'returns :empty_files' do
        expect(subject.download(controller)).to eq(:empty_files)
      end
    end

    context 'when there are non-empty carrier files' do
      it 'creates a zip file and sends it' do
        expect(::Zip::File).to receive(:open).with(zip_path, ::Zip::File::CREATE).and_yield(zip_file)
        expect(carrier_file).to receive(:write_to_zip).with(zip_file)
        expect(controller).to receive(:send_file).with(zip_path, filename: /employer_events_digest_\d{8}_\d{6}\.zip/, type: 'application/zip', disposition: 'attachment')
        expect(File).to receive(:delete).with(zip_path)

        expect(subject.download(controller)).to eq(:success)
      end
    end
  end
end
