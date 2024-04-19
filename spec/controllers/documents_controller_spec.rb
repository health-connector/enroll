# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe DocumentsController, dbclean: :after_each, :type => :controller do
  let(:person) { FactoryGirl.create(:person, :with_hbx_staff_role, :with_consumer_role, :with_family) }
  let(:user) {FactoryGirl.create(:user, :with_hbx_staff_role, :person => person)}
  let!(:permission) { FactoryGirl.create(:permission, :super_admin) }
  let!(:update_admin) { person.hbx_staff_role.update_attributes(permission_id: permission.id) }
  let(:consumer_role) {FactoryGirl.build(:consumer_role)}
  let(:document) {FactoryGirl.build(:vlp_document)}
  let(:family)  {FactoryGirl.create(:family, :with_primary_family_member)}
  let(:hbx_enrollment) { FactoryGirl.build(:hbx_enrollment) }

  # broker role
  let(:broker_agency_profile) { FactoryGirl.create(:benefit_sponsors_organizations_broker_agency_profile, market_kind: :shop) }
  let(:broker_role) { FactoryGirl.create(:broker_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: :active) }
  let!(:broker_role_user) {FactoryGirl.create(:user, :person => broker_role.person, roles: ['broker_role'])}

  # broker staff role
  let(:broker_agency_staff_role) { FactoryGirl.create(:broker_agency_staff_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: 'active')}
  let!(:broker_agency_staff_user) {FactoryGirl.create(:user, :person => broker_agency_staff_role.person, roles: ['broker_agency_staff_role'])}

  before :each do
    sign_in user
  end

  describe "destroy" do
    before :each do
      family_member = FactoryGirl.build(:family_member, person: person, family: family)
      person.families.first.family_members << family_member
      allow(FamilyMember).to receive(:find).with(family_member.id).and_return(family_member)
      person.consumer_role.vlp_documents = [document]
      delete :destroy, person_id: person.id, id: document.id, family_member_id: family_member.id
    end
    it "redirects_to verification page" do
      expect(response).to redirect_to verification_insured_families_path
    end

    it "should delete document record" do
      person.reload
      expect(person.consumer_role.vlp_documents).to be_empty
    end
  end


  describe "GET authorized_download" do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"

    let(:profile) { benefit_sponsorship.organization.profiles.first }
    let(:employer_staff_person) { FactoryGirl.create(:person) }
    let(:employer_staff_user) { FactoryGirl.create(:user, person: employer_staff_person) }
    let(:er_staff_role) { FactoryGirl.create(:benefit_sponsor_employer_staff_role, benefit_sponsor_employer_profile_id: benefit_sponsorship.organization.employer_profile.id) }
    let(:document) {profile.documents.create(identifier: "urn:opentest:terms:t1:test_storage:t3:bucket:test-test-id-verification-test#sample-key")}

    context 'employer staff role' do
      context 'for a user with POC role' do
        before do
          employer_staff_person.employer_staff_roles << er_staff_role
          employer_staff_person.save!
          sign_in employer_staff_user
        end

        it 'current user employer should be able to download' do
          get :authorized_download, model: "BenefitSponsors::Organizations::AcaShopCcaEmployerProfile", model_id: profile.id, relation: "documents", relation_id: document.id

          expect(response).to be_successful
        end
      end

      context 'for a user without POC role' do
        before do
          sign_in employer_staff_user
        end

        it 'current user employer should be able to download' do
          get :authorized_download, model: "BenefitSponsors::Organizations::AcaShopCcaEmployerProfile", model_id: profile.id, relation: "documents", relation_id: document.id

          expect(response).to have_http_status(:found)
          expect(flash[:error]).to eq("Access not allowed for benefit_sponsors/employer_profile_policy.can_download_document?, (Pundit policy)")
        end
      end
    end

    context 'broker role' do
      context 'with authorized account' do
        before do
          profile.broker_agency_accounts << BenefitSponsors::Accounts::BrokerAgencyAccount.new(benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id,
                                                                                               writing_agent_id: broker_role.id,
                                                                                               start_on: Time.now,
                                                                                               is_active: true)
          sign_in broker_role_user
        end

        it 'broker should be able to download' do
          get :authorized_download, model: "BenefitSponsors::Organizations::AcaShopCcaEmployerProfile", model_id: profile.id, relation: "documents", relation_id: document.id
          expect(response).to be_successful
        end
      end

      context 'without authorized account' do
        before do
          sign_in broker_role_user
        end

        it 'broker should be able to download' do
          get :authorized_download, model: "BenefitSponsors::Organizations::AcaShopCcaEmployerProfile", model_id: profile.id, relation: "documents", relation_id: document.id
          expect(response).to have_http_status(:found)
          expect(flash[:error]).to eq("Access not allowed for benefit_sponsors/employer_profile_policy.can_download_document?, (Pundit policy)")
        end
      end
    end

    context 'hbx staff role' do
      context 'with permission to access' do
        before do
          sign_in user
        end

        it 'hbx staff should be able to download' do
          get :authorized_download, model: "BenefitSponsors::Organizations::AcaShopCcaEmployerProfile", model_id: profile.id, relation: "documents", relation_id: document.id
          expect(response).to be_successful
        end
      end

      context 'without permission to access' do
        let!(:permission) { FactoryGirl.create(:permission, :hbx_csr_tier1, modify_employer: false) }
        let!(:update_admin) { person.hbx_staff_role.update_attributes(permission_id: permission.id) }

        before do
          sign_in user
        end

        it 'hbx staff should be able to download' do
          get :authorized_download, model: "BenefitSponsors::Organizations::AcaShopCcaEmployerProfile", model_id: profile.id, relation: "documents", relation_id: document.id
          expect(response).to have_http_status(:found)
          expect(flash[:error]).to eq("Access not allowed for benefit_sponsors/employer_profile_policy.can_download_document?, (Pundit policy)")
        end
      end
    end
  end
end
