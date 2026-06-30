# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifier::NoticeKind, type: :model, dbclean: :after_each do
  let(:site) do
    FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca)
  end

  let(:employer_organization) do
    FactoryBot.create(
      :benefit_sponsors_organizations_general_organization,
      :with_aca_shop_cca_employer_profile,
      site: site
    )
  end

  let(:employer_profile) { employer_organization.employer_profile }

  let(:broker_organization) do
    FactoryBot.create(
      :benefit_sponsors_organizations_general_organization,
      :with_broker_agency_profile,
      site: site
    )
  end

  let(:broker_agency_profile) { broker_organization.broker_agency_profile }

  let(:broker_role) do
    FactoryBot.create(
      :broker_role,
      aasm_state: 'active',
      benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id
    )
  end

  let(:broker_person) { broker_role.person }

  let(:notice_kind) do
    nk = Notifier::NoticeKind.new(title: 'Test Employer Notice', notice_number: 'SHOP001')
    nk.resource = employer_profile
    nk
  end

  before do
    benefit_sponsorship = employer_profile.add_benefit_sponsorship
    benefit_sponsorship.save!
    broker_agency_profile.update_attributes!(primary_broker_role: broker_role)
    broker_role.update_attributes!(broker_agency_profile_id: broker_agency_profile.id)
    broker_agency_profile.approve!
    employer_profile.hire_broker_agency(broker_agency_profile)
    employer_profile.save!
  end

  describe '#send_generic_notice_alert_to_broker' do
    context 'when the resource is an AcaShopCcaEmployerProfile with a broker' do
      before { allow(UserMailer).to receive_message_chain(:generic_notice_alert_to_ba, :deliver_now) }

      it 'sends the broker email notification' do
        notice_kind.send_generic_notice_alert_to_broker

        expect(UserMailer).to have_received(:generic_notice_alert_to_ba).with(
          broker_person.full_name,
          broker_role.email_address,
          employer_organization.legal_name.titleize
        )
      end

      it 'creates an inbox message for the broker' do
        expect { notice_kind.send_generic_notice_alert_to_broker }
          .to change { broker_person.reload.inbox.messages.count }.by(1)
      end
    end

    context 'when the resource has no broker agency profile' do
      before { allow(employer_profile).to receive(:broker_agency_profile).and_return(nil) }

      it 'does not send email or create an inbox message' do
        expect(UserMailer).not_to receive(:generic_notice_alert_to_ba)
        expect { notice_kind.send_generic_notice_alert_to_broker }
          .not_to change { broker_person.reload.inbox.messages.count }
      end
    end

    context 'when the broker agency has no primary broker role' do
      before { allow(broker_agency_profile).to receive(:primary_broker_role).and_return(nil) }

      it 'does not send email or create an inbox message' do
        expect(UserMailer).not_to receive(:generic_notice_alert_to_ba)
        expect { notice_kind.send_generic_notice_alert_to_broker }
          .not_to change { broker_person.reload.inbox.messages.count }
      end
    end

    context 'when the resource is not an AcaShopCcaEmployerProfile' do
      before { notice_kind.resource = double('other_resource') }

      it 'does nothing' do
        expect(UserMailer).not_to receive(:generic_notice_alert_to_ba)
        notice_kind.send_generic_notice_alert_to_broker
      end
    end
  end

  describe '#create_broker_inbox_message' do
    before { broker_person.save! }

    it 'adds a message to the broker inbox' do
      expect { notice_kind.send(:create_broker_inbox_message, broker_person) }
        .to change { broker_person.reload.inbox.messages.count }.by(1)
    end

    it 'sets subject to "New Notice: <title>"' do
      notice_kind.send(:create_broker_inbox_message, broker_person)
      expect(broker_person.reload.inbox.messages.last.subject).to eq("New Notice: #{notice_kind.title}")
    end

    it 'includes the employer legal name in the body' do
      notice_kind.send(:create_broker_inbox_message, broker_person)
      expect(broker_person.reload.inbox.messages.last.body).to include(employer_organization.legal_name.titleize)
    end

    it 'sets from to the site short name' do
      notice_kind.send(:create_broker_inbox_message, broker_person)
      expect(broker_person.reload.inbox.messages.last.from).to eq(notice_kind.site_short_name)
    end

    context 'when the broker person has no inbox' do
      before do
        broker_person.save!
        allow(broker_person).to receive(:inbox).and_return(nil, broker_person.reload.inbox)
      end

      it 'initializes a new inbox without injecting a welcome message' do
        expect(broker_person).to receive(:inbox=).with(instance_of(Inbox)).and_call_original
        expect(broker_person).not_to receive(:create_inbox)
        notice_kind.send(:create_broker_inbox_message, broker_person)
      end
    end
  end
end
