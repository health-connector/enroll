# frozen_string_literal: true

require "rails_helper"
require "base64"

describe Subscribers::BrokerDigestGeneratorSubscriber, "given active broker exists", dbclean: :after_each do
  let(:broker_agency_organization) { FactoryGirl.create(:benefit_sponsors_organizations_general_organization,:with_site,:with_broker_agency_profile)}
  let!(:broker_agency_profile) { broker_agency_organization.broker_agency_profile }
  let!(:person_broker) {FactoryGirl.create(:person,:with_work_email, :with_work_phone)}
  let!(:broker) {FactoryGirl.create(:broker_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: 'active',person: person_broker)}

  subject { Subscribers::BrokerDigestGeneratorSubscriber.new }

  describe "generating a broker digest" do

    it "should notify broker digest published event" do
      expect(subject).to receive(:notify) do |recipient, hash|
        expect(recipient).to eq "acapi.info.events.brokers.broker_digest_published"
        expect(hash[:return_status]).to eq "200"
        expect(hash[:body]).to eq subject.instance_variable_get(:@body)
      end
      return_status = subject.work_with_params(nil, nil, {})
      expect(return_status).to eq :ack
    end

    it "should be valid zip file, with 2 entries" do
      body_result = nil
      expect(subject).to receive(:notify) do |recipient, hash|
        body_result = hash[:body]
      end
      subject.work_with_params(nil, nil, {})
      binary = Base64.decode64(body_result)
      zip_stream = StringIO.new(binary)
      entry_count = 0
      Zip::InputStream.open(zip_stream) do |zstream|
        while (entry = zstream.get_next_entry)
          entry_count = entry_count + 1
        end
      end
      # We expect one for the directory, and one for the file.
      expect(entry_count).to eq 2
    end

    it "is a zip file, with an entry for the XML directory" do
      body_result = nil
      expect(subject).to receive(:notify) do |recipient, hash|
        body_result = hash[:body]
      end
      subject.work_with_params(nil, nil, {})
      binary = Base64.decode64(body_result)
      zip_stream = StringIO.new(binary)
      entry_names = []
      Zip::InputStream.open(zip_stream) do |zstream|
        while (entry = zstream.get_next_entry)
          entry_names << entry.name
        end
      end
      expect(entry_names).to include("broker_xmls/")
    end

    it "is a zip file, with an entry for the single broker XML, by NPN" do
      body_result = nil
      expect(subject).to receive(:notify) do |recipient, hash|
        body_result = hash[:body]
      end
      subject.work_with_params(nil, nil, {})
      binary = Base64.decode64(body_result)
      zip_stream = StringIO.new(binary)
      entry_names = []
      Zip::InputStream.open(zip_stream) do |zstream|
        while (entry = zstream.get_next_entry)
          entry_names << entry.name
        end
      end
      expect(entry_names).to include("broker_xmls/#{broker.npn}.xml")
    end
  end
end