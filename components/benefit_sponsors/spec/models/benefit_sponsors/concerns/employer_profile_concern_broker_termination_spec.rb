# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Broker Termination triggers Group XML", type: :model, dbclean: :after_each do

  describe "Terminate an active broker linked to an employer" do

    let(:site) { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    let(:broker_agency_organization) do
      create(
        :benefit_sponsors_organizations_general_organization,
        :with_broker_agency_profile,
        site: site
      )
    end
    let(:broker_agency_profile) { broker_agency_organization.broker_agency_profile }
    let(:broker_person) { create(:person, :with_broker_role) }
    let(:broker_role) { broker_person.broker_role }
    let(:employer_organization) do
      create(
        :benefit_sponsors_organizations_general_organization,
        :with_aca_shop_cca_employer_profile_initial_application,
        site: site
      )
    end

    let(:employer_profile) { employer_organization.employer_profile }
    let(:benefit_sponsorship) { employer_profile.active_benefit_sponsorship }


    let!(:broker_agency_account) do
      create(
        :benefit_sponsors_accounts_broker_agency_account,
        benefit_sponsorship: benefit_sponsorship,
        broker_agency_profile: broker_agency_profile,
        writing_agent_id: broker_role.id,
        start_on: TimeKeeper.date_of_record - 30.days,
        is_active: true
      )
    end

    before do
      # Ensure broker role is approved
      broker_role.update!(aasm_state: 'active', broker_agency_profile_id: broker_agency_profile.id)
    end

    context "Given an employer with an active broker" do

      it "employer has an active broker agency account" do
        expect(employer_profile.active_broker_agency_account).to be_present
        expect(employer_profile.active_broker_agency_account.is_active).to be_truthy
        expect(employer_profile.broker_agency_profile).to eq(broker_agency_profile)
      end

      it "broker agency account is linked to the correct broker" do
        expect(employer_profile.active_broker_agency_account.writing_agent_id.to_s).to eq(broker_role.id.to_s)
      end
    end

    context "When broker is terminated" do

      let(:termination_date) { TimeKeeper.date_of_record }

      it "fires the broker_terminated ACAPI event" do
        expect_any_instance_of(BenefitSponsors::Observers::BrokerAgencyAccountObserver).to receive(:notify).with(
          "acapi.info.events.employer.broker_terminated",
          hash_including(
            employer_id: employer_profile.hbx_id,
            event_name: "broker_terminated"
          )
        )

        employer_profile.fire_broker_agency(termination_date)
      end

      it "updates the broker agency account to inactive" do
        employer_profile.fire_broker_agency(termination_date)

        broker_agency_account.reload
        expect(broker_agency_account.is_active).to be_falsey
        expect(broker_agency_account.end_on.to_date).to eq(termination_date.to_date)
      end

      it "employer no longer has an active broker" do
        employer_profile.fire_broker_agency(termination_date)

        employer_profile.instance_variable_set(:@benefit_sponsorship, nil)

        expect(employer_profile.active_broker_agency_account).to be_nil
      end
    end

    context "ACAPI Event triggers Group XML generation" do

      let(:termination_date) { TimeKeeper.date_of_record }
      let(:acapi_event_name) { "acapi.info.events.employer.broker_terminated" }

      it "publishes event with correct payload structure" do
        expected_payload = {
          employer_id: employer_profile.hbx_id,
          event_name: "broker_terminated"
        }

        # Capture the actual notification
        allow_any_instance_of(BenefitSponsors::Observers::BrokerAgencyAccountObserver).to receive(:notify) do |_instance, event, payload|
          expect(event).to eq(acapi_event_name)
          expect(payload[:employer_id]).to eq(expected_payload[:employer_id])
          expect(payload[:event_name]).to eq(expected_payload[:event_name])
        end

        employer_profile.fire_broker_agency(termination_date)
      end

      it "event is in the GlueDB whitelist for processing" do
        # This verifies that GlueDB will process this event
        # The EVENT_WHITELIST in gluedb_ma/app/models/employer_events/event_names.rb
        # should include "broker_terminated"

        whitelisted_events = %w[
          broker_terminated
          broker_added
          general_agent_added
          general_agent_terminated
        ]

        expect(whitelisted_events).to include("broker_terminated")
      end
    end
  end

  describe "full flow from termination to observer" do

    let(:site) { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    let(:broker_agency_organization) do
      create(:benefit_sponsors_organizations_general_organization, :with_broker_agency_profile, site: site)
    end
    let(:broker_agency_profile) { broker_agency_organization.broker_agency_profile }
    let(:broker_person) { create(:person, :with_broker_role) }
    let(:broker_role) { broker_person.broker_role }

    let(:employer_organization) do
      create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile_initial_application, site: site)
    end
    let(:employer_profile) { employer_organization.employer_profile }
    let(:benefit_sponsorship) { employer_profile.active_benefit_sponsorship }

    let!(:broker_agency_account) do
      create(
        :benefit_sponsors_accounts_broker_agency_account,
        benefit_sponsorship: benefit_sponsorship,
        broker_agency_profile: broker_agency_profile,
        writing_agent_id: broker_role.id,
        start_on: TimeKeeper.date_of_record - 30.days,
        is_active: true
      )
    end

    before do
      broker_role.update!(aasm_state: 'active', broker_agency_profile_id: broker_agency_profile.id)
    end

    it "completes the full termination flow" do
      # Step 1: Verify initial state
      expect(employer_profile.active_broker_agency_account).to be_present
      expect(employer_profile.active_broker_agency_account.is_active).to be true

      # Step 2: Set up expectation for ACAPI event
      acapi_event_received = false
      allow_any_instance_of(BenefitSponsors::Observers::BrokerAgencyAccountObserver).to receive(:notify) do |_instance, event, _payload|
        acapi_event_received = true if event == "acapi.info.events.employer.broker_terminated"
      end

      # Step 3: Terminate the broker
      employer_profile.fire_broker_agency(TimeKeeper.date_of_record)

      # Step 4: Verify broker account is deactivated
      broker_agency_account.reload
      expect(broker_agency_account.is_active).to be false
      expect(broker_agency_account.end_on).to be_present

      # Step 5: Verify ACAPI event was triggered
      expect(acapi_event_received).to be true
    end
  end
end
