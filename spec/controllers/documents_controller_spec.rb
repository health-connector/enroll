# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe DocumentsController, dbclean: :after_each, :type => :controller do
  let(:person) { FactoryBot.create(:person, :with_hbx_staff_role, :with_consumer_role, :with_family) }
  let(:user) {FactoryBot.create(:user, :with_hbx_staff_role, :person => person)}
  let!(:permission) { FactoryBot.create(:permission, :super_admin) }
  let!(:update_admin) { person.hbx_staff_role.update_attributes(permission_id: permission.id) }
  let(:consumer_role) {FactoryBot.build(:consumer_role)}
  let(:document) {FactoryBot.build(:vlp_document)}
  let(:family)  {FactoryBot.create(:family, :with_primary_family_member)}
  let(:hbx_enrollment) { FactoryBot.build(:hbx_enrollment) }

  # broker role
  let(:broker_agency_profile) { FactoryBot.create(:benefit_sponsors_organizations_broker_agency_profile, market_kind: :shop) }
  let(:broker_role) { FactoryBot.create(:broker_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: :active) }
  let!(:broker_role_user) {FactoryBot.create(:user, :person => broker_role.person, roles: ['broker_role'])}

  # broker staff role
  let(:broker_agency_staff_role) { FactoryBot.create(:broker_agency_staff_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: 'active')}
  let!(:broker_agency_staff_user) {FactoryBot.create(:user, :person => broker_agency_staff_role.person, roles: ['broker_agency_staff_role'])}

  # broker role
  let(:broker_agency_profile) { FactoryBot.create(:benefit_sponsors_organizations_broker_agency_profile, market_kind: :shop) }
  let(:broker_role) { FactoryBot.create(:broker_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: :active) }
  let!(:broker_role_user) {FactoryBot.create(:user, :person => broker_role.person, roles: ['broker_role'])}

  # broker staff role
  let(:broker_agency_staff_role) { FactoryBot.create(:broker_agency_staff_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: 'active')}
  let!(:broker_agency_staff_user) {FactoryBot.create(:user, :person => broker_agency_staff_role.person, roles: ['broker_agency_staff_role'])}

  # employer staff role
  let(:staff_role_status) { 'is_active' }
  let(:employer_staff_role) { FactoryBot.build(:benefit_sponsor_employer_staff_role, aasm_state: staff_role_status, benefit_sponsor_employer_profile_id: abc_profile.id) }
  let(:staff_person) { FactoryBot.create(:person, employer_staff_roles: [employer_staff_role]) }
  let(:er_staff_role_user) {FactoryBot.create(:user, :person => staff_person)}

  let(:admin_user) { user }

  before :each do
    sign_in user
  end

  describe "destroy" do
    before :each do
      family_member = FactoryBot.build(:family_member, person: person, family: family)
      person.families.first.family_members << family_member
      allow(FamilyMember).to receive(:find).with(family_member.id).and_return(family_member)
      person.consumer_role.vlp_documents = [document]
      delete :destroy, params: {person_id: person.id, id: document.id, family_member_id: family_member.id}
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
    let(:employer_staff_person) { FactoryBot.create(:person) }
    let(:employer_staff_user) { FactoryBot.create(:user, person: employer_staff_person) }
    let(:er_staff_role) { FactoryBot.create(:benefit_sponsor_employer_staff_role, benefit_sponsor_employer_profile_id: benefit_sponsorship.organization.employer_profile.id) }
    let(:document) {profile.documents.create(identifier: "urn:opentest:terms:t1:test_storage:t3:bucket:test-test-id-verification-test#sample-key")}

    context 'employer staff role' do
      context 'for a user with POC role' do
        before do
          employer_staff_person.employer_staff_roles << er_staff_role
          employer_staff_person.save!
          sign_in employer_staff_user
        end

        it 'current user employer should be able to download' do
          get :authorized_download, params: { model: "BenefitSponsors::Organizations::AcaShopCcaEmployerProfile", model_id: profile.id, relation: "documents", relation_id: document.id }

          expect(response).to be_successfulful
        end
      end

      context 'for a user without POC role' do
        before do
          sign_in employer_staff_user
        end

        it 'current user employer should be able to download' do
          get :authorized_download, params: { model: "BenefitSponsors::Organizations::AcaShopCcaEmployerProfile", model_id: profile.id, relation: "documents", relation_id: document.id }

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
          get :authorized_download, params: { model: "BenefitSponsors::Organizations::AcaShopCcaEmployerProfile", model_id: profile.id, relation: "documents", relation_id: document.id }
          expect(response).to be_successfulful
        end
      end

      context 'without authorized account' do
        before do
          sign_in broker_role_user
        end

        it 'broker should be able to download' do
          get :authorized_download, params: { model: "BenefitSponsors::Organizations::AcaShopCcaEmployerProfile", model_id: profile.id, relation: "documents", relation_id: document.id }
          expect(response).to have_http_status(:found)
          expect(flash[:error]).to eq("Access not allowed for benefit_sponsors/employer_profile_policy.can_download_document?, (Pundit policy)")
        end
      end
    end

    context 'hbx staff role' do
      context 'with permission to access' do
        before do
          sign_in admin_user
        end

        it 'hbx staff should be able to download' do
          get :authorized_download, params: { model: "BenefitSponsors::Organizations::AcaShopCcaEmployerProfile", model_id: profile.id, relation: "documents", relation_id: document.id }
          expect(response).to be_successfulful
        end
      end

      context 'without permission to access' do
        let!(:permission) { FactoryBot.create(:permission, :hbx_csr_tier1, modify_employer: false) }
        let!(:update_admin) { person.hbx_staff_role.update_attributes(permission_id: permission.id) }

        before do
          sign_in admin_user
        end

        it 'hbx staff should be able to download' do
          get :authorized_download, params: { model: "BenefitSponsors::Organizations::AcaShopCcaEmployerProfile", model_id: profile.id, relation: "documents", relation_id: document.id }
          expect(response).to have_http_status(:found)
          expect(flash[:error]).to eq("Access not allowed for benefit_sponsors/employer_profile_policy.can_download_document?, (Pundit policy)")
        end
      end
    end
  end

  describe "GET employees_template_download" do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"

    let(:profile) { benefit_sponsorship.organization.profiles.first }
    let(:employer_staff_person) { FactoryBot.create(:person) }
    let(:employer_staff_user) { FactoryBot.create(:user, person: employer_staff_person) }
    let(:er_staff_role) { FactoryBot.create(:benefit_sponsor_employer_staff_role, benefit_sponsor_employer_profile_id: benefit_sponsorship.organization.employer_profile.id) }
    let(:document) {profile.documents.create(identifier: "urn:opentest:terms:t1:test_storage:t3:bucket:test-test-id-verification-test#sample-key")}

    context 'employer staff role' do
      context 'for a user with POC role' do
        before do
          employer_staff_person.employer_staff_roles << er_staff_role
          employer_staff_person.save!
          sign_in employer_staff_user
        end

        it 'current user employer should be able to download' do
          get :employees_template_download
          expect(response).to be_successfulful
        end
      end

      context 'for a user without POC role' do

        before do
          sign_in employer_staff_user
        end

        it 'current user without employer staff role should not be able to download' do
          get :employees_template_download
          expect(response).to have_http_status(:found)
          expect(flash[:error]).to eq("Access not allowed for user_policy.can_download_employees_template?, (Pundit policy)")
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
          get :employees_template_download
          expect(response).to be_successfulful
        end
      end

      context 'with inactive broker role' do
        before do
          broker_role.update!(aasm_state: 'inactive')
          sign_in broker_role_user
        end

        it 'broker should be able to download' do
          get :employees_template_download
          expect(response).to have_http_status(:found)
          expect(flash[:error]).to eq("Access not allowed for user_policy.can_download_employees_template?, (Pundit policy)")
        end
      end
    end

    context 'hbx staff role' do
      context 'with permission to access' do
        before do
          sign_in admin_user
        end

        it 'hbx staff should be able to download' do
          get :employees_template_download
          expect(response).to be_successfulful
        end
      end
    end
  end

  describe "GET employer_attestation_document_download" do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"
    let(:document) do
      doc = FactoryBot.create(:employer_attestation_document, identifier: "urn:opentest:terms:t1:test_storage:t3:bucket:test-test-id-verification-test#sample-key")
      doc.employer_attestation.update_attributes(employer_profile: abc_profile)
      doc
    end

    context 'employer staff role' do
      before do
        session[:person_id] = staff_person.id
        sign_in er_staff_role_user
      end

      context 'with authorized account' do

        it 'employer should be able to download' do
          get :employer_attestation_document_download, params: { id: abc_profile.id, document_id: document.id }
          expect(response).to be_successfulful
        end
      end

      context 'with inactive employer staff role' do
        let(:staff_role_status) { nil }

        it 'employer should not be able to download' do
          get :employer_attestation_document_download, params: { id: abc_profile.id, document_id: document.id }
          expect(response).to have_http_status(:found)
          expect(flash[:error]).to eq("Access not allowed for benefit_sponsors/employer_profile_policy.employer_attestation_document_download?, (Pundit policy)")
        end
      end

      context 'staff role with a different employer' do
        let(:organization) { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
        let(:profile) { organization.employer_profile }
        let(:employer_staff_role) { FactoryBot.build(:benefit_sponsor_employer_staff_role, aasm_state: staff_role_status, benefit_sponsor_employer_profile_id: profile.id) }

        it 'employer should not be able to download' do
          get :employer_attestation_document_download, params: { id: abc_profile.id, document_id: document.id }
          expect(response).to have_http_status(:found)
          expect(flash[:error]).to eq("Access not allowed for benefit_sponsors/employer_profile_policy.employer_attestation_document_download?, (Pundit policy)")
        end
      end
    end
  end

  describe "GET product_sbc_download" do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"

    let(:profile) { benefit_sponsorship.organization.profiles.first }
    let(:employee_person) { FactoryBot.create(:person, :with_family, :with_employee_role) }
    let(:census_employee) { FactoryBot.create(:census_employee, employer_profile: profile, employee_role_id: person.employee_role.id) }
    let(:employee_user) { FactoryBot.create(:user, person: employee_person) }
    let(:product) do
      product = FactoryBot.create(:benefit_markets_products_health_products_health_product, benefit_market_kind: :aca_individual, kind: :health, csr_variant_id: '01')
      product.create_sbc_document(identifier: "urn:opentest:terms:t1:test_storage:t3:bucket:test-test-id-verification-test#sample-key")
      product.save
      product
    end

    context 'employee role' do
      context 'for a user with employee role' do
        it 'current user employer should be able to download' do
          sign_in employee_user

          get :product_sbc_download, params: { document_id: product.sbc_document.id, product_id: product.id }
          expect(response).to be_successfulful
        end
      end

      context 'for a user without any role' do
        let(:user_without_roles) { FactoryBot.create(:user, person: FactoryBot.create(:person)) }
        before do
          sign_in user_without_roles
        end

        it 'current user without any role should not be able to download' do
          get :product_sbc_download, params: { document_id: product.sbc_document.id, product_id: product.id }
          expect(response).to have_http_status(:found)
          expect(flash[:error]).to eq("Access not allowed for user_policy.can_download_sbc_documents?, (Pundit policy)")
        end
      end
    end

    context 'broker role' do
      context 'with authorized account' do
        before do
          allow_any_instance_of(ApplicationPolicy).to receive(:active_associated_shop_market_family_broker?).and_return true
          broker_agency_profile.update!(market_kind: 'shop')
          session[:person_id] = employee_person.id
          sign_in broker_role_user
        end

        it 'broker should be able to download' do
          get :product_sbc_download, params: { document_id: product.sbc_document.id, product_id: product.id }
          expect(response).to be_successfulful
        end

        context 'with bqt' do
          let(:plan) do
            plan = FactoryBot.create(:plan)
            plan.create_sbc_document(identifier: "urn:opentest:terms:t1:test_storage:t3:bucket:test-test-id-verification-test#sample-plan-key")
            plan.save
            plan
          end

          it 'broker should be able to download when plan id given' do
            get :product_sbc_download, params: { document_id: plan.sbc_document.id, plan_id: plan.id }
            expect(response).to be_successfulful
          end
        end
      end

      context 'with inactive broker role' do
        before do
          broker_role.update!(aasm_state: 'inactive')
          sign_in broker_role_user
        end

        it 'broker should be able to download' do
          get :product_sbc_download, params: { document_id: product.sbc_document.id, product_id: product.id }, session: { person_id: employee_person.id }
          expect(response).to have_http_status(:found)
          expect(flash[:error]).to eq("Access not allowed for user_policy.can_download_sbc_documents?, (Pundit policy)")
        end
      end
    end

    context 'employer staff role' do
      before do
        session[:person_id] = staff_person.id
        sign_in er_staff_role_user
      end

      context 'with authorized account' do

        it 'employer should be able to download' do
          get :product_sbc_download, params: { document_id: product.sbc_document.id, product_id: product.id }
          expect(response).to be_successfulful
        end
      end

      context 'with inactive employer staff role' do
        let(:staff_role_status) { nil }

        it 'employer should not be able to download' do
          get :product_sbc_download, params: { document_id: product.sbc_document.id, product_id: product.id }
          expect(response).to have_http_status(:found)
          expect(flash[:error]).to eq("Access not allowed for user_policy.can_download_sbc_documents?, (Pundit policy)")
        end
      end
    end

    context 'hbx staff role' do
      context 'with permission to access' do
        before do
          sign_in admin_user
        end

        it 'hbx staff should be able to download' do
          get :product_sbc_download, params: { document_id: product.sbc_document.id, product_id: product.id }
          expect(response).to be_successfulful
        end
      end
    end
  end
end
