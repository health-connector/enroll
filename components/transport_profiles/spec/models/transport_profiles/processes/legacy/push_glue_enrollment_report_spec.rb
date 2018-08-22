require "rails_helper"

module TransportProfiles
  RSpec.describe Processes::Legacy::PushGlueEnrollmentReport do
    describe  "given:
    - a source_uri
    - a gateway
    - a destination file name
    - source credentials
    " do
      let(:source_uri) { double }
      let(:gateway) { double }
      let(:destination_file_name) { double }
      let(:source_credentials) { double }

      subject { TransportProfiles::Processes::Legacy::PushGlueEnrollmentReport.new(source_uri, gateway, destination_file_name: destination_file_name, source_credentials: source_credentials) }

      it "has 2 steps" do
        expect(subject.steps.length).to eq 2
      end
    end

    describe  "given:
    - a source_uri
    - a gateway
    - NO destination file name
    - NO source credentials
    " do
      let(:source_uri) { double }
      let(:gateway) { double }

      subject { TransportProfiles::Processes::Legacy::PushGlueEnrollmentReport.new(source_uri, gateway) }

      it "fails to be created" do
        expect { subject }.to raise_error(ArgumentError, "missing keywords: destination_file_name, source_credentials")
      end
    end
  end
end