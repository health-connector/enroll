require 'rails_helper'

RSpec.describe Employers::EmployerAttestationsController do

  describe "GET edit", dbclean: :after_each do

    let(:user) { FactoryGirl.create(:user) }
    let(:employer_profile) { FactoryGirl.create(:benefit_sponsors_organizations_aca_shop_cca_employer_profile, :with_organization_and_site) }

    it "should render the edit template" do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      sign_in(user)
      xhr :get, :edit, {id: employer_profile.id}
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET new", dbclean: :after_each do
    let(:user) { FactoryGirl.create(:user) }

    it "should render the edit template" do
      sign_in(user)
      xhr :get, :new
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST create", dbclean: :after_each do
    let(:user) { FactoryGirl.create(:user) }
    let(:tempfile) { double(path: 'tmp/sample.pdf') }
    let(:file) { double(original_filename: 'sample.pdf', size: 400, tempfile: tempfile) }
    let(:employer_profile) { FactoryGirl.create(:benefit_sponsors_organizations_aca_shop_cca_employer_profile, :with_organization_and_site) }

    before do 
      allow(controller).to receive(:params).and_return({id: employer_profile.id, file: file})
      allow(Aws::S3Storage).to receive(:save).and_return(doc_uri)

      sign_in(user)
      post :create, {id: employer_profile.id}
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
        expect(employer_profile.employer_attestation.aasm_state).to eq "approved"
        expect(employer_profile.employer_attestation.employer_attestation_documents.first.aasm_state).to eq "submitted"
        expect(flash[:notice]).to eq "File Saved"
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "PUT update", dbclean: :after_each do
    let!(:user) { FactoryGirl.create(:user) }
    let!(:attestation_doc) {FactoryGirl.build(:employer_attestation_document)}
    let!(:employer_attestation) { FactoryGirl.build(:employer_attestation, employer_attestation_documents: [attestation_doc]) }
    let!(:employer_profile) { FactoryGirl.create(:benefit_sponsors_organizations_aca_shop_cca_employer_profile, :with_organization_and_site, employer_attestation: employer_attestation) }

    it "should render the edit template" do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(attestation_doc).to receive(:submit_review).and_return(true)

      sign_in(user)
      put :update, {id: attestation_doc.employer_profile.id, employer_attestation_id: attestation_doc.id, status: 'accepted'}

      expect(flash[:notice]).to eq "Employer attestation updated successfully"
      expect(response).to have_http_status(:redirect)
    end
  end
end
