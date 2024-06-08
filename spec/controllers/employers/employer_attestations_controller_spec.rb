# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe Employers::EmployerAttestationsController, dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  let(:employer_profile) { benefit_sponsorship.organization.profiles.first }
  let(:employer_staff_person) { FactoryBot.create(:person) }
  let(:employer_staff_user) { FactoryBot.create(:user, person: employer_staff_person) }
  let(:er_staff_role) { FactoryBot.create(:benefit_sponsor_employer_staff_role, benefit_sponsor_employer_profile_id: benefit_sponsorship.organization.employer_profile.id) }
  let(:broker_agency_profile) { FactoryBot.create(:benefit_sponsors_organizations_broker_agency_profile, market_kind: :shop) }
  let(:broker_role) { FactoryBot.create(:broker_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: :active) }
  let!(:broker_role_user) { FactoryBot.create(:user, person: broker_role.person, roles: ['broker_role']) }
  let(:broker_agency_staff_role) { FactoryBot.create(:broker_agency_staff_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: 'active') }
  let!(:broker_agency_staff_user) { FactoryBot.create(:user, person: broker_agency_staff_role.person, roles: ['broker_agency_staff_role']) }
  let!(:employer_attestation)   { FactoryBot.build(:employer_attestation, aasm_state: 'unsubmitted') }
  let(:attestation_doc) { employer_profile.employer_attestation.employer_attestation_documents.first }

  before do
    employer_profile.employer_attestation = employer_attestation
    employer_profile.employer_attestation.employer_attestation_documents.create(title: "test", aasm_state: 'submitted')
    employer_profile.save
    employer_profile.reload
    employer_attestation.reload
  end

  context 'as an admin' do
    let!(:admin_person) { FactoryBot.create(:person, :with_hbx_staff_role) }
    let!(:admin_user) { FactoryBot.create(:user, :with_hbx_staff_role, person: admin_person) }
    let!(:permission) { FactoryBot.create(:permission, :super_admin) }
    let!(:update_admin) { admin_person.hbx_staff_role.update_attributes(permission_id: permission.id) }

    before do
      sign_in(admin_user)
    end

    it 'should be a success on GET edit' do
      get :edit, params: { id: employer_profile.id}, format: :js
      expect(response).to have_http_status(:success)
    end

    it 'should be a success on GET new' do
      get :new, format: :js
      expect(response).to have_http_status(:success)
    end

    it 'should be a success on PUT update' do
      put :update, params: { id: employer_profile.id, employer_attestation_id: attestation_doc.id, status: 'accepted'}

      expect(flash[:notice]).to eq "Employer attestation updated successfully"
      expect(response).to have_http_status(:redirect)
    end

    it 'should be a success on GET verify_attestation' do
      get :verify_attestation, params: { :employer_attestation_id => attestation_doc.id}, format: :js
      expect(response).to have_http_status(:success)
    end

    it 'should be a success on delete' do
      delete :delete_attestation_documents, params: { :employer_attestation_id => attestation_doc.id }
      expect(response).to have_http_status(:redirect)
    end

    it "should be a success on PUT update" do
      allow(admin_user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(attestation_doc).to receive(:submit_review).and_return(true)

      sign_in(admin_user)
      put :update, params: { id: employer_profile.id, employer_attestation_id: attestation_doc.id, status: 'accepted'}

      expect(flash[:notice]).to eq "Employer attestation updated successfully"
      expect(response).to have_http_status(:redirect)
    end

    context "POST create" do
      let(:tempfile) { double(path: 'tmp/sample.pdf') }
      let(:file) { double(original_filename: 'sample.pdf', size: 400, tempfile: tempfile) }

      before do
        allow(controller).to receive(:params).and_return({id: employer_profile.id, file: file})
        allow(Aws::S3Storage).to receive(:save).and_return(doc_uri)

        sign_in(admin_user)
        post :create, params: {id: employer_profile.id}
      end

      context 'when file upload failed' do
        let(:doc_uri) { nil }

        it "should render the edit template" do
          expect(flash[:error]).to eq "Could not save the file in S3 storage"
          expect(response).to have_http_status(:redirect)
        end
      end

      context 'when file upload successful' do
        let(:doc_uri) { "urn:openhbx:terms:v1:file_storage:s3:bucket" }

        it 'should return success' do
          employer_profile.reload
          expect(employer_profile.employer_attestation.aasm_state).to eq "submitted"
          expect(employer_profile.employer_attestation.employer_attestation_documents.first.aasm_state).to eq "submitted"
          expect(flash[:notice]).to eq "File Saved"
          expect(response).to have_http_status(:redirect)
        end
      end
    end
  end

  context "with POC role" do
    before do
      employer_staff_person.employer_staff_roles << er_staff_role
      employer_staff_person.save!
      sign_in employer_staff_user
    end

    it "allows the current user to create" do
      post :create, params: {id: employer_profile.id}
      expect(response).to have_http_status(:redirect)
    end
  end

  context "with inactive employer_staff user" do
    before do
      sign_in employer_staff_user
    end

    it "create should show not allowed flash" do
      post :create, params: {id: employer_profile.id}
      expect(flash[:error]).to eq("Access not allowed for benefit_sponsors/employer_profile_policy.employer_attestation_create?, (Pundit policy)")
    end
  end

  context "with an inactive broker role" do
    before do
      broker_role.update!(aasm_state: 'inactive')
      sign_in broker_role_user
    end

    it "create should show not allowed flash" do
      post :create, params: {id: employer_profile.id}
      expect(flash[:error]).to eq("Access not allowed for benefit_sponsors/employer_profile_policy.employer_attestation_create?, (Pundit policy)")
    end
  end

  context "logged in unauthorized user" do
    before do
      person = FactoryBot.create(:person, :with_family)
      unauthorized_user = FactoryBot.create(:user, :person => person)
      sign_in(unauthorized_user)
    end

    it "edit should show not allowed flash" do
      get :edit, params: { id: employer_profile.id}, format: :js
      expect(flash[:error]).to eq("Access not allowed for benefit_sponsors/employer_profile_policy.employer_attestation_edit?, (Pundit policy)")
    end

    it "create should show not allowed flash" do
      post :create, params: {id: employer_profile.id}
      expect(flash[:error]).to eq("Access not allowed for benefit_sponsors/employer_profile_policy.employer_attestation_create?, (Pundit policy)")
    end

    it "delete_attestation_documents should show not allowed flash" do
      delete :delete_attestation_documents, params: { :employer_attestation_id => attestation_doc.id }
      expect(flash[:error]).to eq("Access not allowed for benefit_sponsors/employer_profile_policy.delete_attestation_documents?, (Pundit policy)")
    end

    it "new should show not allowed flash" do
      get :new, format: :js
      expect(flash[:error]).to eq("Access not allowed for user_policy.employer_attestation_new?, (Pundit policy)")
    end

    it "update should show not allowed flash" do
      put :update, params: { id: employer_profile.id, employer_attestation_id: attestation_doc.id, status: 'accepted'}
      expect(flash[:error]).to eq("Access not allowed for benefit_sponsors/employer_profile_policy.employer_attestation_update?, (Pundit policy)")
    end
  end
end
