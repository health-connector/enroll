# frozen_string_literal: true

require "rails_helper"

describe PersonPolicy, dbclean: :after_each do
  let(:person){FactoryBot.create(:person, user: user)}
  let(:user){FactoryBot.create(:user)}
  let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person)}
  let(:policy){PersonPolicy.new(user,person)}
  let(:hbx_profile) {FactoryBot.create(:hbx_profile)}
  Permission.all.delete

  context 'allowed to modify? for hbx_staff_role subroles' do
    it 'hbx_staff' do
      allow(hbx_staff_role).to receive(:permission).and_return(FactoryBot.create(:permission, :hbx_staff))
      expect(policy.can_update?).to be true
    end

    it 'hbx_read_only' do
      allow(hbx_staff_role).to receive(:permission).and_return(FactoryBot.create(:permission, :hbx_read_only))
      expect(policy.updateable?).to be true
    end

    it 'hbx_csr_supervisor' do
      allow(hbx_staff_role).to receive(:permission).and_return(FactoryBot.create(:permission, :hbx_csr_supervisor))
      expect(policy.updateable?).to be true
    end

    it 'hbx_csr_tier2' do
      allow(hbx_staff_role).to receive(:permission).and_return(FactoryBot.create(:permission, :hbx_csr_tier2))
      expect(policy.updateable?).to be true
    end

    it 'csr_tier1' do
      allow(hbx_staff_role).to receive(:permission).and_return(FactoryBot.create(:permission, :hbx_csr_tier1))
      expect(policy.updateable?).to be true
    end

    it 'developer' do
      allow(hbx_staff_role).to receive(:permission).and_return(FactoryBot.create(:permission, :developer))
      expect(policy.updateable?).to be false
    end
  end

  context 'hbx_staff_role subroles' do
    it 'hbx_staff' do
      allow(hbx_staff_role).to receive(:permission).and_return(FactoryBot.create(:permission, :hbx_staff))
      expect(policy.updateable?).to be true
    end

    it 'hbx_read_only' do
      allow(hbx_staff_role).to receive(:permission).and_return(FactoryBot.create(:permission, :hbx_read_only))
      expect(policy.updateable?).to be true
    end

    it 'hbx_csr_supervisor' do
      allow(hbx_staff_role).to receive(:permission).and_return(FactoryBot.create(:permission, :hbx_csr_supervisor))
      expect(policy.updateable?).to be true
    end

    it 'hbx_csr_tier2' do
      allow(hbx_staff_role).to receive(:permission).and_return(FactoryBot.create(:permission, :hbx_csr_tier2))
      expect(policy.updateable?).to be true
    end

    it 'csr_tier1' do
      allow(hbx_staff_role).to receive(:permission).and_return(FactoryBot.create(:permission, :hbx_csr_tier1))
      expect(policy.updateable?).to be true
    end

    it 'developer' do
      allow(hbx_staff_role).to receive(:permission).and_return(FactoryBot.create(:permission, :developer))
      expect(policy.updateable?).to be false
    end
  end


  context "for broker login" do
    let(:site) { FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    let(:broker_organization) { FactoryBot.build(:benefit_sponsors_organizations_general_organization, site: site) }
    let(:broker_agency_profile) { FactoryBot.create(:benefit_sponsors_organizations_broker_agency_profile, organization: broker_organization, market_kind: 'shop', legal_name: 'Legal Name1') }
    let!(:broker_role) { FactoryBot.create(:broker_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: :active) }
    let!(:broker_role_user) {FactoryBot.create(:user, :person => broker_role.person, roles: ['broker_role'])}
    let(:broker_role_person) {broker_role.person}

    let(:broker_organization_2) { FactoryBot.build(:benefit_sponsors_organizations_general_organization, site: site) }
    let(:broker_agency_profile_2) { FactoryBot.create(:benefit_sponsors_organizations_broker_agency_profile, organization: broker_organization_2, market_kind: 'shop', legal_name: 'Legal Name2') }
    let!(:broker_role_2) { FactoryBot.create(:broker_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile_2.id, aasm_state: :active) }
    let!(:broker_role_user_2) {FactoryBot.create(:user, :person => broker_role_2.person, roles: ['broker_role'])}

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

    context 'modify family permissions' do
      let(:organization) {FactoryBot.build(:organization)}
      let(:employer_profile) {FactoryBot.create(:employer_profile, organization: organization)}
      let(:person_2) {FactoryBot.create(:person, :with_family, :with_employee_role)}
      let(:employee_role) {person_2.employee_roles.first}
      let(:census_employee) {FactoryBot.create(:census_employee)}

      let(:broker_organization_3) { FactoryBot.build(:benefit_sponsors_organizations_general_organization, site: site) }
      let(:broker_agency_profile_3) { FactoryBot.create(:benefit_sponsors_organizations_broker_agency_profile, organization: broker_organization_3, market_kind: 'shop', legal_name: 'Legal Name 3') }
      let(:writing_agent) { FactoryBot.create(:broker_role, aasm_state: 'active', benefit_sponsors_broker_agency_profile_id: broker_agency_profile_3.id) }
      let!(:broker_role_3) { FactoryBot.create(:broker_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile_3.id, aasm_state: :active) }
      let!(:broker_role_user_3) {FactoryBot.create(:user, :person => broker_role_3.person, roles: ['broker_role'])}
      let!(:broker_agency_account) { FactoryBot.create(:benefit_sponsors_accounts_broker_agency_account, broker_agency_profile: broker_agency_profile_3) }

      context 'family has associated active broker agency account' do
        let(:policy) {PersonPolicy.new(broker_role_user_3, person_2)}

        before do
          person_2.primary_family.broker_agency_accounts = [broker_agency_account]
        end

        it 'should allow broker to update' do
          expect(policy.can_update?).to be true
        end
      end

      context 'unauthorized broker' do
        let(:policy) {PersonPolicy.new(broker_role_user_2, person_2)}

        it 'should not allow broker to update' do
          expect(policy.can_update?).to be false
        end
      end
    end
  end
end
