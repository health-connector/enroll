# frozen_string_literal: true

require "rails_helper"

describe Subscribers::BrokerDigestGeneratorSubscriber, "given active broker exists" do
  let(:broker_agency_organization) { FactoryGirl.create(:benefit_sponsors_organizations_general_organization,:with_site,:with_broker_agency_profile)}
  let!(:broker_agency_profile) { broker_agency_organization.broker_agency_profile }
  let!(:person_broker) {FactoryGirl.create(:person,:with_work_email, :with_work_phone)}
  let!(:broker) {FactoryGirl.create(:broker_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: 'active',person: person_broker)}

  subject { Subscribers::BrokerDigestGeneratorSubscriber.new }

  describe "should generate broker digest" do

    it "should notify broker digest published event" do
      expect(subject).to receive(:notify) do |recipient, hash|
        expect(recipient).to eq "acapi.info.events.brokers.broker_digest_published"
        expect(hash[:return_status]).to eq "200"
        expect(hash[:body]).to eq subject.instance_variable_get(:@body)
      end
      return_status = subject.work_with_params(nil, nil, {})
      expect(return_status).to eq :ack
    end
  end
end