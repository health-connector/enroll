# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

module BenefitSponsors
  RSpec.describe EmployerProfilePolicy, dbclean: :after_each do
    include_context 'setup benefit market with market catalogs and product packages'
    include_context 'setup initial benefit application'
    let(:policy) { BenefitSponsors::EmployerProfilePolicy.new(user, benefit_sponsorship.organization.profiles.first) }
    let(:person) { FactoryBot.create(:person) }

    context 'for a user with no role' do
      let(:user) { FactoryBot.create(:user, person: person) }

      shared_examples_for 'should not permit for person without employer staff role' do |policy_type|
        it 'should not permit' do
          expect(policy.send(policy_type)).not_to be true
        end
      end

      it_behaves_like 'should not permit for person without employer staff role', :show?
      it_behaves_like 'should not permit for person without employer staff role', :coverage_reports?
      it_behaves_like 'should not permit for person without employer staff role', :updateable?
    end

    context 'for a user without ER staff role' do
      let(:user) { FactoryBot.create(:user, person: person) }
      let(:er_staff_role) { FactoryBot.create(:benefit_sponsor_employer_staff_role, benefit_sponsor_employer_profile_id: benefit_sponsorship.organization.employer_profile.id) }

      shared_examples_for 'should not permit for person without active employer staff role' do |policy_type|
        it 'should not permit for inactive ER staff role' do
          er_staff_role.update_attributes(aasm_state: 'is_closed')
          person.employer_staff_roles << er_staff_role
          expect(policy.send(policy_type)).not_to be true
        end
      end

      it_behaves_like 'should not permit for person without active employer staff role', :show?
      it_behaves_like 'should not permit for person without active employer staff role', :coverage_reports?
      it_behaves_like 'should not permit for person without active employer staff role', :updateable?
    end

    context 'for a user with ER staff role' do
      let(:user) { FactoryBot.create(:user, person: person) }
      let(:er_staff_role) { FactoryBot.create(:benefit_sponsor_employer_staff_role, benefit_sponsor_employer_profile_id: benefit_sponsorship.organization.employer_profile.id) }

      shared_examples_for 'should not permit for person with active employer staff role' do |policy_type|
        it 'should permit for active ER staff role' do
          person.employer_staff_roles << er_staff_role
          expect(policy.send(policy_type)).to be true
        end
      end

      it_behaves_like 'should not permit for person with active employer staff role', :show?
      it_behaves_like 'should not permit for person with active employer staff role', :coverage_reports?
      it_behaves_like 'should not permit for person with active employer staff role', :updateable?
    end

    context 'for a user with admin role' do
      let(:user) { FactoryBot.create(:user, :with_hbx_staff_role, person: person) }
      let(:person) { FactoryBot.create(:person)}
      let(:permission) { FactoryBot.create(:permission, :hbx_staff) }
      let!(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_staff", permission_id: permission.id)}

      shared_examples_for 'should permit for a user with hbx staff role' do |policy_type|
        it 'should permit for admin role' do
          expect(policy.send(policy_type)).to be true
        end
      end

      it_behaves_like 'should permit for a user with hbx staff role', :show?
      it_behaves_like 'should permit for a user with hbx staff role', :run_eligibility_check?
    end

    context '#can_download_document?' do
      let(:er_staff_role) { FactoryBot.create(:benefit_sponsor_employer_staff_role, benefit_sponsor_employer_profile_id: benefit_sponsorship.organization.employer_profile.id) }
      let(:user) { FactoryBot.create(:user, person: person) }

      context 'authorized employer staff' do
        before do
          person.employer_staff_roles << er_staff_role
          person.save!
        end

        it 'employer staff should be able to update' do
          expect(policy.can_download_document?).to be true
        end
      end

      context 'unauthorized employer staff' do
        it 'employer staff should not be able to update' do
          expect(policy.can_download_document?).to be false
        end
      end
    end

    context '#can_read_inbox?' do
      let(:er_staff_role) { FactoryBot.create(:benefit_sponsor_employer_staff_role, benefit_sponsor_employer_profile_id: benefit_sponsorship.organization.employer_profile.id) }
      let(:user) { FactoryBot.create(:user, person: person) }

      context 'authorized employer staff' do
        before do
          person.employer_staff_roles << er_staff_role
          person.save!
        end

        it 'employer staff should be able to update' do
          expect(policy.can_read_inbox?).to be true
        end
      end

      context 'unauthorized employer staff' do
        it 'employer staff should not be able to update' do
          expect(policy.can_read_inbox?).to be false
        end
      end
    end

    context 'for a user with broker role' do
      let(:user) { FactoryBot.create(:user, person: person, roles: ["broker"]) }
      let(:person) { FactoryBot.create(:person) }
      let(:broker_role) { FactoryBot.create(:broker_role, person: person) }
      let!(:broker_organization)    { FactoryBot.build(:benefit_sponsors_organizations_general_organization, site: site)}
      let!(:broker_agency_profile) { FactoryBot.create(:benefit_sponsors_organizations_broker_agency_profile, organization: broker_organization, market_kind: 'shop', legal_name: 'Legal Name1', primary_broker_role: broker_role) }
      let(:employer_profile) {benefit_sponsorship.organization.employer_profile}
      let!(:broker_agency_account) {FactoryBot.build(:benefit_sponsors_accounts_broker_agency_account, broker_agency_profile: broker_agency_profile, writing_agent_id: broker_role.id, is_active: true)}

      shared_examples_for 'should permit for a user with broker role' do |policy_type|
        before do
          employer_profile.broker_agency_accounts << broker_agency_account
          employer_profile.save
        end

        it 'should permit' do
          expect(policy.send(policy_type)).to be true
        end
      end

      it_behaves_like 'should permit for a user with broker role', :show?
      it_behaves_like 'should permit for a user with broker role', :consumer_override?
    end
  end
end
