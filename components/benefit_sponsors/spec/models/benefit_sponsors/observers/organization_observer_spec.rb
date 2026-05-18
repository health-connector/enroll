# frozen_string_literal: true

require 'rails_helper'

module BenefitSponsors
  module Observers
    RSpec.describe OrganizationObserver, type: :model, dbclean: :after_each do
      let!(:organization) { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_site, :with_aca_shop_cca_employer_profile) }
      let(:subject) { BenefitSponsors::Organizations::Organization }
      let(:observer) { OrganizationObserver.new }

      before(:each) do
        allow(observer).to receive(:notify)
      end

      context 'organization legal_name changed' do
        it 'should send notification' do
          expected_payload = { employer_id: organization.hbx_id, event_name: "name_changed" }

          organization.update_attributes(legal_name: "test")
          observer.update(organization)

          BenefitSponsors::Organizations::Organization::FIELD_AND_EVENT_NAMES_MAP.each_key do |key|
            expect(observer).to have_received(:notify).with("acapi.info.events.employer.name_changed", expected_payload) if organization.saved_change_to_attribute(key)
          end
        end

        it 'do not send notification' do
          organization.update_attributes!(dba: "virtual")

          subject.observer_peers.each_key do |observer|
            expect(observer).not_to receive(:notify)
          end
        end
      end

      context 'organization fein changed' do
        before do
          allow(observer).to receive(:notify)
        end

        it 'sends notification' do
          expected_payload = { employer_id: organization.hbx_id, event_name: "fein_corrected" }

          organization.update_attributes(fein: "123456789")
          observer.update(organization)
          expect(observer).to have_received(:notify).with("acapi.info.events.employer.fein_corrected", expected_payload)
        end
      end

      describe '.update' do
        context 'has to send notification when' do
          it 'fein updated' do
            organization.update_attributes(fein: "987654532")
            observer.update(organization, nil)
            expect(observer).to have_received(:notify).with('acapi.info.events.employer.fein_corrected', {:employer_id => organization.hbx_id, :event_name => "fein_corrected"})
          end

          it 'DBA updated' do
            organization.update_attributes(dba: "test")
            observer.update(organization, nil)
            expect(observer).to have_received(:notify).with(
              'acapi.info.events.employer.name_changed',
              { employer_id: organization.hbx_id, event_name: "name_changed" }
            ).exactly(1).time
          end

          it 'legal_name updated' do
            organization.update_attributes(legal_name: "test")
            observer.update(organization, nil)
            expect(observer).to have_received(:notify).with('acapi.info.events.employer.name_changed', {:employer_id => organization.hbx_id, :event_name => "name_changed"})
          end
        end
      end
    end
  end
end
