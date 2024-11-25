# frozen_string_literal: true

require 'rails_helper'
require 'zip'

RSpec.describe BenefitSponsors::Services::GroupXmlDownloader, type: :service do
  let(:employer_event) { double('EmployerEvent') }
  let(:carrier_file) { double('CarrierFile', rendered_employers: ['employer1'], render_reason: :success) }
  let(:empty_carrier_file) { double('EmptyCarrierFile', rendered_employers: [], render_reason: :no_carrier_plan_years) }
  let(:zip_file) { Tempfile.new(['employer_events_digest', '.zip']) }
  let(:zip_path) { zip_file.path }
  subject { described_class.new(employer_event) }

  before do
    allow(employer_event).to receive(:render_payloads).and_return([carrier_file, empty_carrier_file])
    allow(Rails.logger).to receive(:info)
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

      it 'returns :empty_files with reasons' do
        expect(subject.download).to eq([:empty_files, "Reasons: No carrier plan years available"])
      end
    end

    context 'when there are non-empty carrier files' do
      it 'creates a zip file and returns success with zip path' do
        expect(Tempfile).to receive(:new).with("employer_events_digest").and_return(double(path: zip_path, close: nil, unlink: nil))

        expect(Zip::File).to receive(:open) do |path, create_flag, &block|
          expect(path).to match(/employer_events_digest.*\.zip$/)
          expect(create_flag).to eq(Zip::File::CREATE)
          block.call(zip_file)
        end

        expect(carrier_file).to receive(:write_to_zip).with(zip_file)
        result = subject.download
        expect(result.first).to eq(:success)
        expect(result.last).to match(/employer_events_digest.*\.zip$/)
      end
    end
  end
end
