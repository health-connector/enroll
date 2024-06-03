# frozen_string_literal: true

require "rails_helper"

describe PersonPolicy do
  context 'with hbx_staff_role' do
    let(:person){FactoryGirl.create(:person, user: user)}
    let(:user){FactoryGirl.create(:user)}
    let(:hbx_staff_role) { FactoryGirl.create(:hbx_staff_role, person: person)}
    let(:policy){PersonPolicy.new(user,person)}
    let(:hbx_profile) {FactoryGirl.create(:hbx_profile)}
    Permission.all.delete

    context 'allowed to modify? for hbx_staff_role subroles' do
      it 'hbx_staff' do
        allow(hbx_staff_role).to receive(:permission).and_return(FactoryGirl.create(:permission, :hbx_staff))
        expect(policy.can_update?).to be true
      end

      it 'hbx_read_only' do
        allow(hbx_staff_role).to receive(:permission).and_return(FactoryGirl.create(:permission, :hbx_read_only))
        expect(policy.updateable?).to be true
      end

      it 'hbx_csr_supervisor' do
        allow(hbx_staff_role).to receive(:permission).and_return(FactoryGirl.create(:permission, :hbx_csr_supervisor))
        expect(policy.updateable?).to be true
      end

      it 'hbx_csr_tier2' do
        allow(hbx_staff_role).to receive(:permission).and_return(FactoryGirl.create(:permission, :hbx_csr_tier2))
        expect(policy.updateable?).to be true
      end

      it 'csr_tier1' do
        allow(hbx_staff_role).to receive(:permission).and_return(FactoryGirl.create(:permission, :hbx_csr_tier1))
        expect(policy.updateable?).to be true
      end

      it 'developer' do
        allow(hbx_staff_role).to receive(:permission).and_return(FactoryGirl.create(:permission, :developer))
        expect(policy.updateable?).to be false
      end
    end

    context 'hbx_staff_role subroles' do
      it 'hbx_staff' do
        allow(hbx_staff_role).to receive(:permission).and_return(FactoryGirl.create(:permission, :hbx_staff))
        expect(policy.updateable?).to be true
      end

      it 'hbx_read_only' do
        allow(hbx_staff_role).to receive(:permission).and_return(FactoryGirl.create(:permission, :hbx_read_only))
        expect(policy.updateable?).to be true
      end

      it 'hbx_csr_supervisor' do
        allow(hbx_staff_role).to receive(:permission).and_return(FactoryGirl.create(:permission, :hbx_csr_supervisor))
        expect(policy.updateable?).to be true
      end

      it 'hbx_csr_tier2' do
        allow(hbx_staff_role).to receive(:permission).and_return(FactoryGirl.create(:permission, :hbx_csr_tier2))
        expect(policy.updateable?).to be true
      end

      it 'csr_tier1' do
        allow(hbx_staff_role).to receive(:permission).and_return(FactoryGirl.create(:permission, :hbx_csr_tier1))
        expect(policy.updateable?).to be true
      end

      it 'developer' do
        allow(hbx_staff_role).to receive(:permission).and_return(FactoryGirl.create(:permission, :developer))
        expect(policy.updateable?).to be false
      end
    end
  end

  context 'with broker role' do
    Permission.all.delete

    let(:consumer_role) do
      FactoryGirl.create(:consumer_role)
    end

    let(:person) do
      pers = consumer_role.person
      pers.user = user
      pers.save!
      pers
    end

    let(:broker_agency_profile) do
      FactoryGirl.create(:benefit_sponsors_organizations_broker_agency_profile)
    end

    let(:user) do
      FactoryGirl.create(:user)
    end

    let(:existing_broker_staff_role) do
      person.broker_agency_staff_roles.first
    end

    let(:broker_role) do
      role = BrokerRole.new(
        :broker_agency_profile => broker_agency_profile,
        :aasm_state => "applicant",
        :npn => "123456789",
        :provider_kind => "broker"
      )
      person.broker_role = role
      person.save!
      person.broker_role
    end

    let(:policy){PersonPolicy.new(user,person)}

    it 'broker should be able to update' do
      expect(policy.can_update?).to be true
    end

  end

  context "for broker login" do
    let(:site) { FactoryGirl.create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    let(:broker_organization) { FactoryGirl.build(:benefit_sponsors_organizations_general_organization, site: site) }
    let(:broker_agency_profile) { FactoryGirl.create(:benefit_sponsors_organizations_broker_agency_profile, organization: broker_organization, market_kind: 'shop', legal_name: 'Legal Name1') }
    let!(:broker_role) { FactoryGirl.create(:broker_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: :active) }
    let!(:broker_role_user) {FactoryGirl.create(:user, :person => broker_role.person, roles: ['broker_role'])}
    let(:broker_role_person) {broker_role.person}

    let(:broker_organization_2) { FactoryGirl.build(:benefit_sponsors_organizations_general_organization, site: site) }
    let(:broker_agency_profile_2) { FactoryGirl.create(:benefit_sponsors_organizations_broker_agency_profile, organization: broker_organization_2, market_kind: 'shop', legal_name: 'Legal Name2') }
    let!(:broker_role_2) { FactoryGirl.create(:broker_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile_2.id, aasm_state: :active) }
    let!(:broker_role_user_2) {FactoryGirl.create(:user, :person => broker_role_2.person, roles: ['broker_role'])}

    context 'with broker role' do

      context 'authorized broker' do
        let(:policy) {PersonPolicy.new(broker_role_user, broker_role_person)}

        it 'broker should be able to update' do
          expect(policy.can_download_document?).to be true
        end
      end

      context 'unauthorized broker' do
        let(:policy) {PersonPolicy.new(broker_role_user_2, broker_role_person)}

        it 'broker should not be able to update' do
          expect(policy.can_download_document?).to be false
        end
      end
    end
  end
end
