# frozen_string_literal: true

require 'rails_helper'
require 'tempfile'
require 'zip'


RSpec.describe BenefitSponsors::Services::GroupXmlDownloader, :dbclean => :after_each do
  let(:employer_event) { instance_double(BenefitSponsors::Services::EmployerEvent) }
  let(:controller) { instance_double(ActionController::Base) }
  let(:downloader) { described_class.new(employer_event) }

  describe '#download' do
    let(:carrier_file1) { instance_double(BenefitSponsors::EmployerEvents::CarrierFile) }
    let(:carrier_file2) { instance_double(BenefitSponsors::EmployerEvents::CarrierFile) }
    let(:tempfile) { Tempfile.new("employer_events_digest") }
    let(:zip_path) { "#{tempfile.path}.zip" }

    before do
      allow(employer_event).to receive(:render_payloads).and_return([carrier_file1, carrier_file2])

      allow(Tempfile).to receive(:new).with("employer_events_digest").and_return(tempfile)
      allow(tempfile).to receive(:close)
      allow(tempfile).to receive(:unlink)

      allow(::Zip::File).to receive(:open).with(zip_path, ::Zip::File::CREATE).and_yield(zip_path)
      allow(carrier_file1).to receive(:write_to_zip)
      allow(carrier_file2).to receive(:write_to_zip)

      allow(controller).to receive(:send_file)
    end

    it 'generates a ZIP file with carrier files and sends it to the controller' do
      expect(::Zip::File).to receive(:open).with(zip_path, ::Zip::File::CREATE).and_yield(zip_path)
      expect(carrier_file1).to receive(:write_to_zip)
      expect(carrier_file2).to receive(:write_to_zip)
      expect(controller).to receive(:send_file).with(zip_path)

      downloader.download(controller)
    end
  end
end
