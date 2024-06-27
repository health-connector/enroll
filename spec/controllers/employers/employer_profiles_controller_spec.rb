# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Employers::EmployerProfilesController, dbclean: :after_each do
  let(:user) { FactoryBot.create(:user) }
  let(:admin_user) { FactoryBot.create(:user, :with_hbx_staff_role) }
  let!(:hbx_person) { FactoryBot.create(:person, user: admin_user)}
  let!(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: hbx_person) }
  let(:employer_profile) { FactoryBot.create(:employer_profile) }

  before do
    allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', modify_employer: true))
  end

  describe "GET index"  do
    it 'should redirect' do
      sign_in(admin_user)
      get :index
      expect(response).to redirect_to("/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor")
    end

    context "without permissions" do
      it "should return an error" do
        sign_in(user)
        get :delete_documents, params: {id: employer_profile.id, ids: [1]}
        expect(flash[:error]).to match(/Access not allowed for employer_profile_policy/)
      end
    end
  end

  describe "GET new" do
    it "should redirect" do
      sign_in(admin_user)
      get :new
      expect(response).to redirect_to("/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor")
    end

    context "without permissions" do
      it "should return an error" do
        sign_in(user)
        get :delete_documents, params: {id: employer_profile.id, ids: [1]}
        expect(flash[:error]).to match(/Access not allowed for employer_profile_policy/)
      end
    end
  end

  describe "GET show_profile" do
    it "should redirect" do
      sign_in(admin_user)
      get :show_profile, params: { employer_profile_id: employer_profile }
      expect(response).to redirect_to("/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor")
    end

    context "without permissions" do
      it "should return an error" do
        sign_in(user)
        get :delete_documents, params: {id: employer_profile.id, ids: [1]}
        expect(flash[:error]).to match(/Access not allowed for employer_profile_policy/)
      end
    end
  end

  describe "GET show" do
    it "should redirect" do
      sign_in(admin_user)
      get :show, params: { id: employer_profile }
      expect(response).to redirect_to("/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor")
    end

    context "without permissions" do
      it "should return an error" do
        sign_in(user)
        get :delete_documents, params: {id: employer_profile.id, ids: [1]}
        expect(flash[:error]).to match(/Access not allowed for employer_profile_policy/)
      end
    end
  end

  describe "GET welcome", dbclean: :after_each do
    it "should redirect" do
      sign_in(admin_user)
      get :welcome
      expect(response).to redirect_to("/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor")
    end

    context "without permissions" do
      it "should return an error" do
        sign_in(user)
        get :delete_documents, params: {id: employer_profile.id, ids: [1]}
        expect(flash[:error]).to match(/Access not allowed for employer_profile_policy/)
      end
    end
  end


  describe "GET search", dbclean: :after_each do
    before(:each) do
      sign_in admin_user
      get :search
    end

    it "renders the 'search' template" do
      expect(response).to have_http_status(:success)
      expect(response).to render_template("search")
      expect(assigns[:employer_profile]).to be_a(Forms::EmployerCandidate)
    end

    context "without permissions" do
      it "should return an error" do
        sign_in(user)
        get :delete_documents, params: {id: employer_profile.id, ids: [1]}
        expect(flash[:error]).to match(/Access not allowed for employer_profile_policy/)
      end
    end
  end


  describe "GET export_census_employees", dbclean: :after_each do
    it "should export cvs" do
      sign_in(admin_user)
      get :export_census_employees, params: { employer_profile_id: employer_profile}, format: :csv
      expect(response).to have_http_status(:success)
    end

    context "without permissions" do
      it "should return an error" do
        sign_in(user)
        get :delete_documents, params: {id: employer_profile.id, ids: [1]}
        expect(flash[:error]).to match(/Access not allowed for employer_profile_policy/)
      end
    end
  end

  describe "GET new Document", dbclean: :after_each do
    it "should load upload Page" do
      sign_in(admin_user)
      get :new_document, params: {id: employer_profile}, format: :js
      expect(response).to have_http_status(:success)
    end

    context "without permissions" do
      it "should return an error" do
        sign_in(user)
        get :delete_documents, params: {id: employer_profile.id, ids: [1]}
        expect(flash[:error]).to match(/Access not allowed for employer_profile_policy/)
      end
    end
  end

  describe "POST Upload Document", dbclean: :after_each do
    #let(:params) { { id: employer_profile.id, file:'test/JavaScript.pdf', subject: 'JavaScript.pdf' } }

    let(:subject){"Employee Attestation"}
    let(:file) { double }
    let(:temp_file) { double }
    let(:file_path) { Rails.root.join("spec", "test_data", "files", "JavaScript.pdf") }

    before(:each) do
      @controller = Employers::EmployerProfilesController.new
      #allow(file).to receive(:original_filename).and_return("some-filename")
      allow(file).to receive(:tempfile).and_return(temp_file)
      allow(temp_file).to receive(:path)
      allow(@controller).to receive(:file_path).and_return(file_path)
      allow(@controller).to receive(:file_name).and_return("sample-filename")
      #allow(@controller).to receive(:file_content_type).and_return("application/pdf")
    end

    context "upload document", dbclean: :after_each do
      it "redirects to document list page" do
        sign_in admin_user
        post :upload_document, params: {:id => employer_profile.id, :file => file, :subject => subject}
        expect(response).to have_http_status(:redirect)
      end
    end

    context "without permissions" do
      it "should return an error" do
        sign_in(user)
        get :delete_documents, params: {id: employer_profile.id, ids: [1]}
        expect(flash[:error]).to match(/Access not allowed for employer_profile_policy/)
      end
    end
  end

  describe "Delete Document", dbclean: :after_each do
    it "should delete documents" do
      sign_in(admin_user)
      get :delete_documents, params: {id: employer_profile.id, ids: [1]}, format: :js
      expect(response).to have_http_status(:success)
    end

    context "without permissions" do
      it "should return an error" do
        sign_in(user)
        get :delete_documents, params: {id: employer_profile.id, ids: [1]}
        expect(flash[:error]).to match(/Access not allowed for employer_profile_policy/)
      end
    end
  end
end
