# frozen_string_literal: true

require 'rails_helper'
require File.join(Rails.root, "components/benefit_sponsors/spec/support/benefit_sponsors_product_spec_helpers")
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe Exchanges::HbxProfilesController, dbclean: :after_each do

  describe "various index" do
    let(:user) { double("user", :has_hbx_staff_role? => true, :has_employer_staff_role? => false)}
    let(:person) { double("person")}
    let(:permission) { double(view_admin_tabs: true) }
    let(:hbx_staff_role) { double("hbx_staff_role", permission: permission)}
    let(:hbx_profile) { double("HbxProfile")}

    before :each do
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(user).to receive(:person).and_return(person)
      allow(person).to receive(:hbx_staff_role).and_return(hbx_staff_role)
      allow(hbx_staff_role).to receive(:hbx_profile).and_return(hbx_profile)

      sign_in(user)
    end

    it "renders index" do
      get :index
      expect(response).to have_http_status(:success)
      expect(response).to render_template("exchanges/hbx_profiles/index")
    end

    it "renders broker_agency_index" do
      get :broker_agency_index, xhr: true
      expect(response).to have_http_status(:success)
      expect(response).to render_template("exchanges/hbx_profiles/broker_agency_index")
    end

    it "renders issuer_index" do
      get :issuer_index, xhr: true
      expect(response).to have_http_status(:success)
      expect(response).to render_template("exchanges/hbx_profiles/issuer_index")
    end

    it "renders product_index" do
      get :product_index, xhr: true
      expect(response).to have_http_status(:success)
      expect(response).to render_template("exchanges/hbx_profiles/product_index")
    end
  end

  describe "binder methods" do
    let(:user) { double("user")}
    let(:person) { double("person")}
    let(:hbx_profile) { double("HbxProfile") }
    let(:hbx_staff_role) { double("hbx_staff_role", permission: FactoryBot.create(:permission))}
    let(:employer_profile){ FactoryBot.create(:employer_profile, aasm_state: "enrolling") }

    before(:each) do
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(user).to receive(:person).and_return(person)
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(person).to receive(:hbx_staff_role).and_return(hbx_staff_role)
      allow(hbx_staff_role).to receive(:hbx_profile).and_return(hbx_profile)
      sign_in(user)
    end

    it "renders binder_index" do
      get :binder_index, xhr: true
      expect(response).to have_http_status(:success)
      expect(response).to render_template("exchanges/hbx_profiles/binder_index")
    end

    it "should render json template" do
      get :binder_index_datatable, params: { format: :json }
      expect(response).to render_template("exchanges/hbx_profiles/binder_index_datatable")
    end

  end

  describe "new" do
    let(:user) { double("User")}
    let(:person) { double("Person")}

    it "renders new" do
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      sign_in(user)
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe "inbox" do
    let(:user) { double("User")}
    let(:person) { double("Person")}
    let(:hbx_staff_role) { double("hbx_staff_role")}
    let(:hbx_profile) { double("HbxProfile", id: double("id"))}

    it "renders inbox" do
      allow(user).to receive(:person).and_return(person)
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(person).to receive(:hbx_staff_role).and_return(hbx_staff_role)
      allow(hbx_staff_role).to receive(:hbx_profile).and_return(hbx_profile)
      sign_in(user)
      get :inbox, params: { id: hbx_profile.id}, xhr: true
      expect(response).to have_http_status(:success)
    end

  end

  describe "employer_invoice" do
    let(:user) { double("User")}
    let(:person) { double("Person")}
    let(:hbx_staff_role) { double("hbx_staff_role")}
    let(:hbx_profile) { double("HbxProfile", id: double("id"))}
    let(:search_params){{"value" => ""}}

    before :each do
      allow(user).to receive(:person).and_return(person)
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(person).to receive(:hbx_staff_role).and_return(hbx_staff_role)
      allow(hbx_staff_role).to receive(:hbx_profile).and_return(hbx_profile)
      sign_in(user)
    end

    it "renders employer_invoice datatable" do
      get :employer_invoice, xhr: true
      expect(response).to have_http_status(:success)
    end

    it "renders employer_invoice datatable payload" do
      post :employer_invoice_datatable, params: { :search => search_params }, xhr: true
      expect(response).to have_http_status(:success)
    end

  end

  describe "Action # employer_datatable" do
    let(:user) { double(:user, has_hbx_staff_role?: true, last_portal_visited: "www.google.com")}

    before :each do
      sign_in(user)
    end

    it "renders employer_datatable as JS" do
      get :employer_datatable, format: :js
      expect(response).not_to redirect_to("www.google.com")
      expect(response).to render_template("exchanges/hbx_profiles/employer_datatable")
    end

    it "renders employer_datatable as HTML" do
      # Open the link in new tab/ new browser "employers" link
      get :employer_datatable, format: :html
      expect(response).to redirect_to("www.google.com")
    end
  end
=begin
  describe "#create" do
    let(:user) { double("User")}
    let(:person) { double("Person")}
    let(:hbx_staff_role) { double("hbx_staff_role")}
    let(:hbx_profile) { double("HbxProfile", id: double("id"))}
    let(:organization){ Organization.new }
    let(:organization_params) { {hbx_profile: {organization: organization.attributes}}}

    before :each do
      sign_in(user)
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(Organization).to receive(:new).and_return(organization)
      allow(organization).to receive(:build_hbx_profile).and_return(hbx_profile)
    end

    it "create new organization if params valid" do
      allow(hbx_profile).to receive(:save).and_return(true)
      post :create, organization_params
      expect(response).to have_http_status(:redirect)
    end

    it "renders new if params invalid" do
      allow(hbx_profile).to receive(:save).and_return(false)
      post :create, organization_params
      expect(response).to render_template("exchanges/hbx_profiles/new")
    end
  end

  describe "#update" do
    let(:user) { FactoryBot.create(:user, :hbx_staff) }
    let(:person) { double }
    let(:new_hbx_profile){ HbxProfile.new }
    let(:hbx_profile) { FactoryBot.create(:hbx_profile) }
    let(:hbx_profile_params) { {hbx_profile: new_hbx_profile.attributes, id: hbx_profile.id }}
    let(:hbx_staff_role) {double}

    before :each do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(user).to receive(:person).and_return person
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(HbxProfile).to receive(:find).and_return(hbx_profile)
      allow(person).to receive(:hbx_staff_role).and_return hbx_staff_role
      allow(hbx_staff_role).to receive(:hbx_profile).and_return hbx_profile
      sign_in(user)
    end

    it "updates profile" do
      allow(hbx_profile).to receive(:update).and_return(true)
      put :update, hbx_profile_params
      expect(response).to have_http_status(:redirect)
    end

    it "renders edit if params not valid" do
      allow(hbx_profile).to receive(:update).and_return(false)
      put :update, hbx_profile_params
      expect(response).to render_template("edit")
    end
  end

  describe "#destroy" do
    let(:user){ double("User") }
    let(:person){ double("Person") }
    let(:hbx_profile) { FactoryBot.create(:hbx_profile) }
    let(:hbx_staff_role) {double}

    it "destroys hbx_profile" do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(user).to receive(:person).and_return person
      allow(person).to receive(:hbx_staff_role).and_return hbx_staff_role
      allow(hbx_staff_role).to receive(:hbx_profile).and_return hbx_profile
      allow(HbxProfile).to receive(:find).and_return(hbx_profile)
      allow(hbx_profile).to receive(:destroy).and_return(true)
      sign_in(user)
      delete :destroy, id: hbx_profile.id
      expect(response).to have_http_status(:redirect)
    end

  end
=end

  describe "#check_hbx_staff_role" do
    let(:user) { double("user")}
    let(:person) { double("person")}

    it "should render the new template" do
      allow(user).to receive(:has_hbx_staff_role?).and_return(false)
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      sign_in(user)
      get :new
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "#view_the_configuration_tab?" do
    let(:user) { double("user", :has_hbx_staff_role? => true, :has_employer_staff_role? => false)}
    let(:user_2) { double("user", :has_hbx_staff_role? => true, :has_employer_staff_role? => false)}
    let(:person) { double("person")}
    let(:hbx_staff_role) { double("hbx_staff_role")}
    let(:hbx_profile) { double("hbx_profile")}
    let(:admin_permission) { double("permission", name: "super_admin", view_the_configuration_tab: true)}
    let(:admin_permission_with_time_travel) { double("permission", name: "super_admin", can_submit_time_travel_request: true, modify_admin_tabs: true)}
    let(:staff_permission) { double("permission", name: "hbx_staff")}

    before :each do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(user).to receive(:person).and_return(person)
      allow(person).to receive(:hbx_staff_role).and_return(hbx_staff_role)
      allow(person).to receive(:hbx_staff_role).and_return(hbx_staff_role)
      allow(hbx_staff_role).to receive(:hbx_profile).and_return(hbx_profile)
      allow(hbx_staff_role).to receive(:can_submit_time_travel_request).and_return(false)
      allow(hbx_staff_role).to receive(:view_the_configuration_tab)
      allow(user).to receive(:permission).and_return(admin_permission)
    end

    it "should render the config index for a super admin" do
      allow(hbx_staff_role).to receive(:view_the_configuration_tab).and_return(true)
      allow(hbx_staff_role).to receive(:permission).and_return(admin_permission)
      allow(hbx_staff_role).to receive(:subrole).and_return(admin_permission.name)
      allow(admin_permission).to receive(:name).and_return(admin_permission.name)
      allow(admin_permission).to receive(:can_submit_time_travel_request).and_return(false)
      allow(admin_permission).to receive(:view_the_configuration_tab).and_return(true)
      allow(admin_permission).to receive(:modify_family).and_return(true)
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(user).to receive(:view_the_configuration_tab?).and_return(true)
      allow(user).to receive(:can_submit_time_travel_request?).and_return(false)
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      sign_in(user)
      get :configuration
      expect(response).to have_http_status(:success)
      post :set_date, params: { :forms_time_keeper => { :date_of_record => TimeKeeper.date_of_record.next_day.strftime('%Y-%m-%d') } }
      expect(response).to have_http_status(:redirect)
    end

    it "should not render the config index for a not super admin" do
      allow(admin_permission).to receive(:view_the_configuration_tab).and_return(false)
      allow(admin_permission).to receive(:modify_family).and_return(true)
      allow(staff_permission).to receive(:view_the_configuration_tab).and_return(true)
      allow(staff_permission).to receive(:modify_family).and_return(true)
      allow(hbx_staff_role).to receive(:view_the_configuration_tab).and_return(false)
      allow(hbx_staff_role).to receive(:permission).and_return(staff_permission)
      allow(hbx_staff_role).to receive(:subrole).and_return(staff_permission.name)
      allow(staff_permission).to receive(:name).and_return(staff_permission.name)
      allow(user_2).to receive(:has_hbx_staff_role?).and_return(true)
      allow(user_2).to receive(:person).and_return(person)

      allow(user_2).to receive(:permission).and_return(staff_permission)

      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      sign_in(user_2)
      get :configuration
      expect(response).to have_http_status(:success)
    end

    it "should not allow super admin to time travel" do
      allow(admin_permission).to receive(:view_the_configuration_tab).and_return(true)
      allow(staff_permission).to receive(:view_the_configuration_tab).and_return(true)
      allow(hbx_staff_role).to receive(:permission).and_return(staff_permission)
      allow(hbx_staff_role).to receive(:view_the_configuration_tab).and_return(true)
      allow(hbx_staff_role).to receive(:subrole).and_return(staff_permission.name)
      allow(admin_permission).to receive(:can_submit_time_travel_request).and_return(false)
      allow(user_2).to receive(:has_hbx_staff_role?).and_return(true)
      allow(user).to receive(:view_the_configuration_tab?).and_return(true)
      allow(user_2).to receive(:view_the_configuration_tab?).and_return(false)
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(user).to receive(:permission).and_return(admin_permission)
      sign_in(user)
      post :set_date, params: { :forms_time_keeper => { :date_of_record => TimeKeeper.date_of_record.next_day.strftime('%Y-%m-%d') } }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "Show" do
    let(:user) { double("user", :has_hbx_staff_role? => true, :has_employer_staff_role? => false, :has_csr_role? => false, :last_portal_visited => nil)}
    let(:person) { double("person")}
    let(:hbx_staff_role) { double("hbx_staff_role")}
    let(:hbx_profile) { double("hbx_profile", inbox: double("inbox", unread_messages: double("test")))}
    let(:admin_permission) { double("permission", name: "super_admin", modify_family: true)}

    before :each do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(user).to receive(:person).and_return(person)
      allow(user).to receive(:last_portal_visited=).with("http://test.host/exchanges/hbx_profiles")
      allow(user).to receive(:save)
      allow(person).to receive(:hbx_staff_role).and_return(hbx_staff_role)
      allow(hbx_staff_role).to receive(:hbx_profile).and_return(hbx_profile)
      allow(hbx_staff_role).to receive(:permission).and_return(admin_permission)
      session[:dismiss_announcements] = 'hello'
      sign_in(user)
    end

    it "renders 'show' " do
      get :show
      expect(response).to have_http_status(:success)
      expect(response).to render_template("exchanges/hbx_profiles/show")
    end

    it "should clear session for dismiss_announcements" do
      get :show
      expect(session[:dismiss_announcements]).to eq nil
    end
  end

  describe "#generate_invoice" do
    let(:user) { double("user", :has_hbx_staff_role? => true)}
    let(:employer_profile) { double("EmployerProfile", id: double("id"))}
    let(:organization){ Organization.new }
    let(:family) { FactoryBot.build(:family, :with_primary_family_member_and_dependent)}
    let(:hbx_enrollment) { FactoryBot.create(:hbx_enrollment, household: family.active_household)}

    before :each do
      sign_in(user)
      allow(organization).to receive(:employer_profile?).and_return(employer_profile)
      allow(employer_profile).to receive(:enrollments_for_billing).and_return([hbx_enrollment])
    end

    it "create new organization if params valid" do
      get :generate_invoice, params: {"employerId" => [organization.id], ids: [organization.id]},  format: :js
      expect(response).to have_http_status(:success)
      # expect(organization.invoices.size).to eq 1
    end
  end

  describe "GET edit_force_publish", :dbclean => :around_each do

    context "of an hbx super admin clicks Force Publish" do
      let(:site) do
        FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca)
      end
      let(:employer_organization) do
        FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site).tap do |org|
          benefit_sponsorship = org.employer_profile.add_benefit_sponsorship
          benefit_sponsorship.save
        end
      end
      let(:person) do
        FactoryBot.create(:person, :with_hbx_staff_role).tap do |person|
          FactoryBot.create(:permission, :super_admin).tap do |permission|
            person.hbx_staff_role.update_attributes(permission_id: permission.id)
          end
        end
      end
      let(:user) do
        FactoryBot.create(:user, person: person)
      end
      let(:benefit_sponsorship) do
        employer_organization.benefit_sponsorships.first
      end

      it "renders edit_force_publish" do
        sign_in(user)
        @params = {id: benefit_sponsorship.id.to_s, employer_actions_id: "employer_actions_#{employer_organization.employer_profile.id}", :format => 'js'}
        get :edit_force_publish, params: @params, xhr: true
        expect(response).to render_template('edit_force_publish')
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "POST force_publish" do

    context "of an hbx super admin clicks Submit in Force Publish window" do
      let(:site) do
        FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca)
      end
      let(:employer_organization) do
        FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site).tap do |org|
          benefit_sponsorship = org.employer_profile.add_benefit_sponsorship
          benefit_sponsorship.save
        end
      end
      let(:person) do
        FactoryBot.create(:person, :with_hbx_staff_role).tap do |person|
          FactoryBot.create(:permission, :super_admin).tap do |permission|
            person.hbx_staff_role.update_attributes(permission_id: permission.id)
          end
        end
      end
      let(:user) do
        FactoryBot.create(:user, person: person)
      end
      let(:benefit_sponsorship) do
        employer_organization.benefit_sponsorships.first
      end

      it "renders force_publish" do
        sign_in(user)
        @params = {id: benefit_sponsorship.id.to_s, employer_actions_id: "employer_actions_#{employer_organization.employer_profile.id}", :format => 'js'}
        post :force_publish, params: @params, xhr: true
        expect(response).to render_template('force_publish')
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "CSR redirection from Show" do
    let(:user) { double("user", :has_hbx_staff_role? => false, :has_employer_staff_role? => false, :has_csr_role? => true, :last_portal_visited => nil)}
    let(:person) { double("person")}
    let(:hbx_staff_role) { double("hbx_staff_role")}
    let(:hbx_profile) { double("hbx_profile", inbox: double("inbox", unread_messages: double("test")))}

    before :each do
      allow(user).to receive(:has_csr_role?).and_return(true)
      allow(user).to receive(:last_portal_visited=).with("http://test.host/exchanges/hbx_profiles")
      allow(user).to receive(:save)
      allow(user).to receive(:has_role?).with(:csr).and_return true
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return false
      allow(user).to receive(:person).and_return(person)
      sign_in(user)
      get :show
    end

    it "redirects to agents/home " do
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET employer index" do
    let(:user) { double("user", :has_hbx_staff_role? => true, :has_employer_staff_role? => false)}
    let(:person) { double("person")}
    let(:hbx_staff_role) { double("hbx_staff_role")}
    let(:hbx_profile) { double("hbx_profile")}

    before :each do
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(user).to receive(:person).and_return(person)
      allow(person).to receive(:hbx_staff_role).and_return(hbx_staff_role)
      expect(controller).to receive(:find_hbx_profile)
      allow(controller).to receive(:cur_page_no).and_return("1")
      allow(hbx_staff_role).to receive(:hbx_profile).and_return(hbx_profile)
      sign_in(user)
      get :employer_index
    end

    it "renders the 'employer index' template" do
      expect(response).to have_http_status(:success)
      expect(response).to render_template("employers/employer_profiles/index")
    end
  end

  describe "GET family index" do
    let(:user) { double("User")}
    let(:person) { double("Person")}
    let(:hbx_staff_role) { double("hbx_staff_role")}
    let(:hbx_profile) { double("hbx_profile")}
    let(:csr_role) { double("csr_role", cac: false)}
    let(:admin_permission) { double("permission", name: "super_admin", modify_family: true)}

    before :each do
      allow(person).to receive(:csr_role).and_return(double("csr_role", cac: false))
      allow(user).to receive(:person).and_return(person)
      sign_in(user)
    end

    it "renders the 'families index' template for hbx_staff" do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(person).to receive(:hbx_staff_role).and_return(hbx_staff_role)
      allow(hbx_staff_role).to receive(:permission).and_return(admin_permission)
      get :family_index
      expect(response).to have_http_status(:success)
      expect(response).to render_template("insured/families/index")
    end

    it "renders the 'families index' template for csr" do
      allow(user).to receive(:has_hbx_staff_role?).and_return(false)
      allow(person).to receive(:hbx_staff_role).and_return(hbx_staff_role)
      allow(hbx_staff_role).to receive(:permission).and_return(admin_permission)
      get :family_index
      expect(response).to have_http_status(:success)
      expect(response).to render_template("insured/families/index")
    end

    it "redirects if not csr or hbx_staff 'families index' template for hbx_staff" do
      allow(user).to receive(:has_hbx_staff_role?).and_return(false)
      allow(person).to receive(:csr_role).and_return(false)
      get :family_index
      expect(response).to redirect_to(root_url)
    end

    it "redirects if not csr or hbx_staff 'families index' template for hbx_staff" do
      allow(user).to receive(:has_hbx_staff_role?).and_return(false)
      allow(person).to receive(:csr_role).and_return(double("csr_role", cac: true))
      get :family_index
      expect(response).to redirect_to(root_url)
    end
  end

  describe "GET configuration index" do
    let(:user) { double("user", :has_hbx_staff_role? => true, :has_employer_staff_role? => false)}
    let(:person) { double("person")}
    let(:hbx_staff_role) { double("hbx_staff_role")}
    let(:hbx_profile) { double("hbx_profile")}
    let(:permission) { double("permission", name: "hbx_staff", view_the_configuration_tab: false)}


    before :each do
      allow(hbx_staff_role).to receive(:view_the_configuration_tab).and_return(true)
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(user).to receive(:person).and_return(person)
      allow(user).to receive(:permission).and_return(permission)
      allow(person).to receive(:hbx_staff_role).and_return(hbx_staff_role)
      allow(hbx_staff_role).to receive(:hbx_profile).and_return(hbx_profile)
      allow(hbx_staff_role).to receive(:permission).and_return(permission)
      allow(hbx_staff_role).to receive(:subrole).and_return(permission.name)

      allow(hbx_staff_role).to receive(:subrole).and_return(permission.name)

      allow(permission).to receive(:name).and_return(permission.name)
      allow(permission).to receive(:modify_family).and_return(true)
      allow(permission).to receive(:view_the_configuration_tab).and_return(true)
      sign_in(user)
      get :configuration
    end

    it "should render the configuration partial" do
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:partial => 'exchanges/hbx_profiles/_configuration_index')
    end
  end

  describe "POST" do
    let(:user) { FactoryBot.create(:user)}
    let(:person) { FactoryBot.create(:person, user: user) }
    let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person) }
    let(:time_keeper_form) { instance_double(Forms::TimeKeeper) }

    before :each do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', modify_admin_tabs: true))
      sign_in(user)
    end

    it "sends timekeeper a date" do
      timekeeper_form_params = { :date_of_record =>  TimeKeeper.date_of_record.next_day.strftime('%Y-%m-%d') }
      allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', modify_admin_tabs: true, can_submit_time_travel_request: false, name: "hbx_staff", view_the_configuration_tab: false))

      allow(Forms::TimeKeeper).to receive(:new).with(timekeeper_form_params).and_return(time_keeper_form)
      allow(time_keeper_form).to receive(:forms_date_of_record).and_return(TimeKeeper.date_of_record.next_day.strftime('%Y-%m-%d'))
      sign_in(user)
      post :set_date, params: { :forms_time_keeper => { :date_of_record => TimeKeeper.date_of_record.next_day.strftime('%Y-%m-%d') } }
      expect(response).to have_http_status(:redirect)
    end

    it "sends timekeeper a date and fails because not updateable" do
      allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', modify_admin_tabs: false, can_submit_time_travel_request: false, name: "hbx_staff", view_the_configuration_tab: false))
      sign_in(user)
      expect(TimeKeeper).not_to receive(:set_date_of_record).with(TimeKeeper.date_of_record.next_day.strftime('%Y-%m-%d'))
      post :set_date, params: { :forms_time_keeper => { :date_of_record => TimeKeeper.date_of_record.next_day.strftime('%Y-%m-%d') } }
      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to match(/Access not allowed/)
    end

    it "update setting" do
      Setting.individual_market_monthly_enrollment_due_on
      allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', modify_admin_tabs: true))
      sign_in(user)

      post :update_setting, params: { :setting => {'name' => 'individual_market_monthly_enrollment_due_on', 'value' => 15} }
      expect(response).to have_http_status(:redirect)
      expect(Setting.individual_market_monthly_enrollment_due_on).to eq 15
    end

    it "update setting fails because not updateable" do
      allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', modify_admin_tabs: false))
      sign_in(user)
      post :update_setting, params: { :setting => {'name' => 'individual_market_monthly_enrollment_due_on', 'value' => 19} }
      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to match(/Access not allowed/)
    end
  end

  describe "GET edit_dob_ssn" do

    let(:person) { FactoryBot.create(:person, :with_consumer_role, :with_employee_role) }
    let(:user) { double("user", :person => person, :has_hbx_staff_role? => true) }
    let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person)}
    let(:hbx_profile) { FactoryBot.create(:hbx_profile)}
    let(:permission_yes) { FactoryBot.create(:permission, :can_update_ssn => true)}
    let(:permission_no) { FactoryBot.create(:permission, :can_update_ssn => false)}

    it "should return authorization error for Non-Admin users" do
      allow(hbx_staff_role).to receive(:permission).and_return permission_yes
      sign_in(user)
      @params = {:id => person.id, :format => 'js'}
      get :edit_dob_ssn, params: @params, xhr: true
      expect(response).to have_http_status(:success)
    end

    it "should render the edit_dob_ssn partial for logged in users with an admin role" do
      allow(hbx_staff_role).to receive(:permission).and_return permission_yes
      sign_in(user)
      @params = {:id => person.id, :format => 'js'}
      get :edit_dob_ssn, params: @params, xhr: true
      expect(response).to have_http_status(:success)
    end

  end


  describe "POST update_dob_ssn" do

    let(:person) { FactoryBot.create(:person, :with_consumer_role, :with_employee_role) }
    let(:person1) { FactoryBot.create(:person) }
    let(:user) { double("user", :person => person, :has_hbx_staff_role? => true) }
    let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person)}
    let(:hbx_profile) { FactoryBot.create(:hbx_profile)}
    let(:permission_yes) { FactoryBot.create(:permission, :can_update_ssn => true)}
    let(:permission_no) { FactoryBot.create(:permission, :can_update_ssn => false)}
    let(:invalid_ssn) { "234-45-839" }
    let(:valid_ssn) { "234-45-8390" }
    let(:valid_dob) { "03/17/1987" }

    it "should render back to edit_enrollment if there is a validation error on save" do
      allow(hbx_staff_role).to receive(:permission).and_return permission_yes
      sign_in(user)
      @params = {:person => {:pid => person.id, :ssn => invalid_ssn, :dob => valid_dob},:jq_datepicker_ignore_person => {:dob => valid_dob}, :format => 'js'}
      get :update_dob_ssn, params: @params, xhr: true
      expect(response).to render_template('edit_enrollment')
    end

    it "should render update_enrollment if the save is successful" do
      allow(hbx_staff_role).to receive(:permission).and_return permission_yes
      sign_in(user)
      expect(response).to have_http_status(:success)
      @params = {:person => {:pid => person.id, :ssn => valid_ssn, :dob => valid_dob },:jq_datepicker_ignore_person => {:dob => valid_dob}, :format => 'js'}
      get :update_dob_ssn, params: @params, xhr: true
      expect(response).to render_template('update_enrollment')
    end

    it "should render update enrollment if the save is successful" do
      allow(hbx_staff_role).to receive(:permission).and_return permission_yes
      sign_in(user)
      expect(response).to have_http_status(:success)
      @params = {:person => {:pid => person1.id, :ssn => "", :dob => valid_dob },:jq_datepicker_ignore_person => {:dob => valid_dob}, :format => 'js'}
      get :update_dob_ssn, params: @params, xhr: true
      expect(response).to render_template('update_enrollment')
    end

    it "should return authorization error for Non-Admin users" do
      allow(user).to receive(:has_hbx_staff_role?).and_return false
      sign_in(user)
      get :update_dob_ssn, xhr: true
      expect(response).not_to have_http_status(:success)
    end

  end

  describe "GET general_agency_index" do
    let(:user) { FactoryBot.create(:user, roles: ["hbx_staff"]) }
    before :each do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      sign_in user
    end

    context "when GA is enabled in settings" do
      before do
        Settings.aca.general_agency_enabled = true
        Enroll::Application.reload_routes!
      end
      it "should returns http success" do
        get :general_agency_index, format: :js
        expect(response).to have_http_status(:success)
      end

      it "should get general_agencies" do
        get :general_agency_index, format: :js
        expect(assigns(:general_agency_profiles)).to eq Kaminari.paginate_array(GeneralAgencyProfile.filter_by)
      end
    end

    context "when GA is disabled in settings" do
      before do
        Settings.aca.general_agency_enabled = false
        Enroll::Application.reload_routes!
      end
      it "should returns http success" do
        expect(:get => :general_agency_index).not_to be_routable
      end
    end
  end

  describe "POST reinstate_enrollment", :dbclean => :around_each do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"
    include_context "setup employees with benefits"

    let(:user) { FactoryBot.create(:user, roles: ["hbx_staff"]) }
    let!(:person) { FactoryBot.create(:person)}
    let(:current_effective_date)  { TimeKeeper.date_of_record }
    let(:benefit_market)      { site.benefit_markets.first }

    let(:issuer_profile)  { FactoryBot.create :benefit_sponsors_organizations_issuer_profile, assigned_site: site}
    let(:product_package_kind) { :single_product}
    let!(:product_package) { current_benefit_market_catalog.product_packages.where(package_kind: product_package_kind).first }
    let(:product) { product_package.products.first }

    # let!(:employer_profile) {benefit_sponsorship.profile}
    # let!(:initial_application) { create(:benefit_sponsors_benefit_application, benefit_sponsor_catalog: benefit_sponsor_catalog, effective_period: effective_period,benefit_sponsorship:benefit_sponsorship, aasm_state: :active) }
    let(:product_package)           { initial_application.benefit_sponsor_catalog.product_packages.detect { |package| package.package_kind == package_kind } }
    let!(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person)}
    # let!(:household) { FactoryBot.create(:household, family: family) }
    # let!(:site)                { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    # let!(:benefit_market)      { site.benefit_markets.first }
    # let!(:organization)        { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
    # let!(:employer_profile)    { organization.employer_profile }
    # let(:benefit_sponsor)        { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile_initial_application, site: site) }
    # let(:benefit_sponsorship)    { benefit_sponsor.active_benefit_sponsorship }
    # let(:benefit_application)    { benefit_sponsorship.benefit_applications.first }
    let(:benefit_package)    { initial_application.benefit_packages.first }
    # let(:benefit_group_assignment) {FactoryBot.build(:benefit_group_assignment, benefit_group: benefit_package)}

    let!(:enrollment) do
      family.active_household.hbx_enrollments.create!(
        household: family.active_household,
        coverage_kind: "health",
        product: product,
        effective_on: TimeKeeper.date_of_record.last_month.beginning_of_month,
        aasm_state: 'coverage_termination_pending',
        kind: "employer_sponsored",
        benefit_sponsorship: benefit_sponsorship,
        sponsored_benefit_package: benefit_package,
        terminated_on: TimeKeeper.date_of_record.end_of_month
      )
    end

    before :each do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      sign_in user
    end

    it "should redirect to root path" do
      post :reinstate_enrollment, params: { enrollment_id: enrollment.id }, format: :js, xhr: true
      expect(response).to have_http_status(:success)
      expect(response).to redirect_to(exchanges_hbx_profiles_root_path)
    end
  end

  describe "POST view_enrollment_to_update_end_date", :dbclean => :around_each do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"
    include_context "setup employees with benefits"

    let(:user) { FactoryBot.create(:user, roles: ["hbx_staff"]) }
    let!(:person) { FactoryBot.create(:person)}
    let(:current_effective_date)  { TimeKeeper.date_of_record.beginning_of_year - 1.year }
    let(:primary) { family.primary_family_member }
    let(:dependents) { family.dependents }
    let!(:household) { FactoryBot.create(:household, family: family) }
    let!(:hbx_en_member1) { FactoryBot.build(:hbx_enrollment_member, eligibility_date: current_effective_date, coverage_start_on: current_effective_date, applicant_id: dependents.first.id) }
    let!(:hbx_en_member2) { FactoryBot.build(:hbx_enrollment_member, eligibility_date: current_effective_date + 2.months, coverage_start_on: current_effective_date + 2.months, applicant_id: hbx_en_member1.applicant_id) }
    let!(:hbx_en_member3) { FactoryBot.build(:hbx_enrollment_member, eligibility_date: current_effective_date + 6.months, coverage_start_on: current_effective_date + 6.months, applicant_id: dependents.last.id) }
    let(:benefit_market)      { site.benefit_markets.first }

    let(:issuer_profile)  { FactoryBot.create :benefit_sponsors_organizations_issuer_profile, assigned_site: site}
    let(:product_package_kind) { :single_product}
    let!(:product_package) { current_benefit_market_catalog.product_packages.where(package_kind: product_package_kind).first }
    let(:product) { product_package.products.first }
    let(:product_package)           { initial_application.benefit_sponsor_catalog.product_packages.detect { |package| package.package_kind == package_kind } }
    let!(:family) { FactoryBot.create(:family, :with_primary_family_member_and_dependent, person: person)}
    let(:benefit_package)    { initial_application.benefit_packages.first }
    let!(:enrollment1)  do
      FactoryBot.create(:hbx_enrollment, household: family.active_household, coverage_kind: "health", product: product, effective_on: current_effective_date, aasm_state: 'coverage_terminated', kind: "employer_sponsored",
                                         hbx_enrollment_members: [hbx_en_member1], benefit_sponsorship: benefit_sponsorship, sponsored_benefit_package: benefit_package, terminated_on: current_effective_date.next_month.end_of_month)
    end

    let!(:enrollment2)  do
      FactoryBot.create(:hbx_enrollment, household: family.active_household, coverage_kind: "health", product: product, effective_on: current_effective_date + 2.months, aasm_state: 'coverage_terminated', kind: "employer_sponsored",
                                         hbx_enrollment_members: [hbx_en_member2], benefit_sponsorship: benefit_sponsorship, sponsored_benefit_package: benefit_package, terminated_on: (current_effective_date + 5.months).end_of_month)
    end

    let!(:enrollment3)  do
      FactoryBot.create(:hbx_enrollment, household: family.active_household, coverage_kind: "health", product: product, effective_on: current_effective_date + 6.months, aasm_state: 'coverage_terminated', kind: "employer_sponsored",
                                         hbx_enrollment_members: [hbx_en_member3], benefit_sponsorship: benefit_sponsorship, sponsored_benefit_package: benefit_package, terminated_on: current_effective_date.end_of_year)
    end

    before :each do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      sign_in user
    end

    it "should render template" do
      post :view_enrollment_to_update_end_date, params: {person_id: person.id.to_s, family_actions_id: family.id}, format: :js
      expect(response).to have_http_status(:success)
      expect(response).to render_template("view_enrollment_to_update_end_date")
    end

    it "should get duplicate enrollment id's" do
      post :view_enrollment_to_update_end_date, params: {person_id: person.id.to_s, family_actions_id: family.id}, format: :js
      expect(assigns(:dup_enr_ids).include?(enrollment1.id.to_s)).to eq true
      expect(assigns(:dup_enr_ids).include?(enrollment3.id.to_s)).to eq false
    end
  end

  describe "POST update_enrollment_termianted_on_date", :dbclean => :around_each do
    let(:user) { FactoryBot.create(:user, roles: ["hbx_staff"]) }
    let!(:person) { FactoryBot.create(:person)}
    let!(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person)}
    let!(:household) { FactoryBot.create(:household, family: family) }
    let!(:enrollment) do
      FactoryBot.create(:hbx_enrollment,
                        household: family.active_household,
                        coverage_kind: "health",
                        kind: 'employer_sponsored',
                        effective_on: TimeKeeper.date_of_record.last_month.beginning_of_month,
                        terminated_on: TimeKeeper.date_of_record.next_month.end_of_month,
                        aasm_state: 'coverage_termination_pending')
    end
    let!(:glue_event_queue_name) { "#{Rails.application.config.acapi.hbx_id}.#{Rails.application.config.acapi.environment_name}.q.glue.enrollment_event_batch_handler" }


    before :each do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      sign_in user
    end

    context "shop enrollment" do
      context "with valid params" do

        it "should render template " do
          post :update_enrollment_termianted_on_date, params: { enrollment_id: enrollment.id.to_s, family_actions_id: family.id, new_termination_date: TimeKeeper.date_of_record.to_s}, format: :js
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(exchanges_hbx_profiles_root_path)
        end

        context "enrollment that already terminated with past date" do
          context "with new past or current termination date" do
            it "should update enrollment with new end date and notify enrollment" do
              expect_any_instance_of(HbxEnrollment).to receive(:notify).with("acapi.info.events.hbx_enrollment.terminated",
                                                                             {:reply_to => glue_event_queue_name, "hbx_enrollment_id" => enrollment.hbx_id, "enrollment_action_uri" => "urn:openhbx:terms:v1:enrollment#terminate_enrollment",
                                                                              "is_trading_partner_publishable" => false})
              post :update_enrollment_termianted_on_date, params: {enrollment_id: enrollment.id.to_s, family_actions_id: family.id, new_termination_date: TimeKeeper.date_of_record.to_s}, format: :js
              enrollment.reload
              expect(enrollment.aasm_state).to eq "coverage_terminated"
              expect(enrollment.terminated_on).to eq TimeKeeper.date_of_record
            end
          end

        end

        context "enrollment that already terminated with future date" do
          context "with new future termination date" do
            it "should update enrollment with new end date and notify enrollment" do
              expect_any_instance_of(HbxEnrollment).to receive(:notify).with("acapi.info.events.hbx_enrollment.terminated",
                                                                             {:reply_to => glue_event_queue_name, "hbx_enrollment_id" => enrollment.hbx_id, "enrollment_action_uri" => "urn:openhbx:terms:v1:enrollment#terminate_enrollment",
                                                                              "is_trading_partner_publishable" => false})
              post :update_enrollment_termianted_on_date, params: {enrollment_id: enrollment.id.to_s, family_actions_id: family.id, new_termination_date: (TimeKeeper.date_of_record + 1.day).to_s}, format: :js
              enrollment.reload
              expect(enrollment.aasm_state).to eq "coverage_termination_pending"
              expect(enrollment.terminated_on).to eq TimeKeeper.date_of_record + 1.day
            end
          end
        end
      end
    end

    context "IVL enrollment", :dbclean => :around_each do

      before do
        enrollment.kind = "individual"
        enrollment.save
      end

      context "with valid params" do

        it "should render template " do
          post :update_enrollment_termianted_on_date, params: {enrollment_id: enrollment.id.to_s, family_actions_id: family.id, new_termination_date: TimeKeeper.date_of_record.to_s}, format: :js
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(exchanges_hbx_profiles_root_path)
        end

        context "enrollment that already terminated with past date" do
          context "with new past or current termination date" do
            it "should update enrollment with new end date and notify enrollment" do
              expect_any_instance_of(HbxEnrollment).to receive(:notify).with("acapi.info.events.hbx_enrollment.terminated",
                                                                             {:reply_to => glue_event_queue_name, "hbx_enrollment_id" => enrollment.hbx_id, "enrollment_action_uri" => "urn:openhbx:terms:v1:enrollment#terminate_enrollment",
                                                                              "is_trading_partner_publishable" => false})
              post :update_enrollment_termianted_on_date, params: {enrollment_id: enrollment.id.to_s, family_actions_id: family.id, new_termination_date: TimeKeeper.date_of_record.to_s}, format: :js, xhr: true
              enrollment.reload
              expect(enrollment.aasm_state).to eq "coverage_terminated"
              expect(enrollment.terminated_on).to eq TimeKeeper.date_of_record
            end
          end

        end

        context "enrollment that already terminated with future date" do
          context "with new future termination date" do
            it "should update enrollment with new end date and notify enrollment" do
              expect_any_instance_of(HbxEnrollment).to receive(:notify).with("acapi.info.events.hbx_enrollment.terminated",
                                                                             {:reply_to => glue_event_queue_name, "hbx_enrollment_id" => enrollment.hbx_id, "enrollment_action_uri" => "urn:openhbx:terms:v1:enrollment#terminate_enrollment",
                                                                              "is_trading_partner_publishable" => false})
              post :update_enrollment_termianted_on_date, params: { enrollment_id: enrollment.id.to_s, family_actions_id: family.id, new_termination_date: (TimeKeeper.date_of_record + 1.day).to_s}, format: :js
              enrollment.reload
              expect(enrollment.aasm_state).to eq "coverage_terminated"
              expect(enrollment.terminated_on).to eq TimeKeeper.date_of_record + 1.day
            end
          end
        end
      end
    end

    context "with invalid params" do
      it "should redirect to root path" do
        post :update_enrollment_termianted_on_date, params: { enrollment_id: '', family_actions_id: '', new_termination_date: ''}, format: :js
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(exchanges_hbx_profiles_root_path)
      end
    end

  end

  describe "GET get_user_info" do
    let(:user) { double("User", :has_hbx_staff_role? => true)}
    let(:person) { double("Person", id: double)}
    let(:family_id) { double("Family_ID")}
    let(:employer_id) { double("Employer_ID") }
    let(:organization) { double("Organization")}

    before do
      sign_in user
      allow(Person).to receive(:find).with(person.id.to_s).and_return person
      allow(EmployerProfile).to receive(:find).and_return(double(organization: organization))
    end

    context "when action called through families datatable" do

      before do
        get :get_user_info, params: { family_actions_id: family_id, person_id: person.id }, format: :js, xhr: true
      end

      it "should populate the person instance variable" do
        expect(assigns(:person)).to eq person
      end

      it "should populate the row id to instance variable" do
        expect(assigns(:element_to_replace_id)).to eq family_id.to_s
      end
    end

    context "when action called through employers datatable" do

      before do
        allow(Organization).to receive(:find).and_return organization
        get :get_user_info, params: { employers_action_id: employer_id, people_id: [person.id] }, format: :js, xhr: true
      end

      it "should not populate the person instance variable" do
        expect(assigns(:person)).to eq nil
      end

      it "should populate the people instance variable" do
        expect(assigns(:people).class).to eq Mongoid::Criteria
      end

      it "should populate the employer_actions instance variable" do
        expect(assigns(:employer_actions)).to eq true
      end

      it "should populate the row id to instance variable" do
        expect(assigns(:element_to_replace_id)).to eq employer_id.to_s
      end
    end
  end

  describe "extend open enrollment" do

    let(:user) { double("user", :has_hbx_staff_role? => true, :has_employer_staff_role? => false)}
    let(:person) { double("person")}
    let(:permission) { double(can_extend_open_enrollment: true) }
    let(:hbx_staff_role) { double("hbx_staff_role", permission: permission)}
    let(:hbx_profile) { double("HbxProfile")}
    let(:benefit_sponsorship) { double(benefit_applications: benefit_applications) }
    let(:benefit_applications) { [double]}

    before :each do
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(user).to receive(:person).and_return(person)
      allow(person).to receive(:hbx_staff_role).and_return(hbx_staff_role)
      allow(hbx_staff_role).to receive(:hbx_profile).and_return(hbx_profile)
      allow(BenefitSponsors::BenefitSponsorships::BenefitSponsorship).to receive(:find).and_return(benefit_sponsorship)
      sign_in(user)
    end

    context '.oe_extendable_applications' do
      let(:benefit_applications) { [double(may_extend_open_enrollment?: true)]}

      before do
        allow(benefit_sponsorship).to receive(:oe_extendable_benefit_applications).and_return(benefit_applications)
      end

      it "renders open enrollment extendable applications" do
        get :oe_extendable_applications, xhr: true

        expect(response).to have_http_status(:success)
        expect(response).to render_template("exchanges/hbx_profiles/oe_extendable_applications")
      end
    end

    context '.oe_extended_applications' do
      let(:benefit_applications) { [double(enrollment_extended?: true)]}

      before do
        allow(benefit_sponsorship).to receive(:oe_extended_applications).and_return(benefit_applications)
      end

      it "renders open enrollment extended applications" do
        get :oe_extended_applications, xhr: true

        expect(response).to have_http_status(:success)
        expect(response).to render_template("exchanges/hbx_profiles/oe_extended_applications")
      end
    end

    context '.edit_open_enrollment' do
      let(:benefit_application) { double }

      before do
        allow(benefit_applications).to receive(:find).and_return(benefit_application)
      end

      it "renders edit open enrollment" do
        get :edit_open_enrollment, xhr: true

        expect(response).to have_http_status(:success)
        expect(response).to render_template("exchanges/hbx_profiles/edit_open_enrollment")
      end
    end

    context '.extend_open_enrollment' do
      let(:benefit_application) { double }

      before do
        allow(benefit_applications).to receive(:find).and_return(benefit_application)
        allow(BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService).to receive_message_chain(:new,:extend_open_enrollment).and_return(true)
      end

      it "renders index" do
        post :extend_open_enrollment, params: { open_enrollment_end_date: "11/26/2018" }

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(exchanges_hbx_profiles_root_path)
      end
    end
  end

  describe "close open enrollment", :dbclean => :around_each do

    let(:user) { double("user", :has_hbx_staff_role? => true, :has_employer_staff_role? => false)}
    let(:person) { double("person")}
    let(:permission) { double(can_extend_open_enrollment: true) }
    let(:hbx_staff_role) { double("hbx_staff_role", permission: permission)}
    let(:hbx_profile) { double("HbxProfile")}
    let(:benefit_sponsorship) { double(benefit_applications: benefit_applications) }
    let(:benefit_applications) { [double]}

    before :each do
      allow(user).to receive(:has_role?).with(:hbx_staff).and_return true
      allow(user).to receive(:person).and_return(person)
      allow(person).to receive(:hbx_staff_role).and_return(hbx_staff_role)
      allow(hbx_staff_role).to receive(:hbx_profile).and_return(hbx_profile)
      allow(BenefitSponsors::BenefitSponsorships::BenefitSponsorship).to receive(:find).and_return(benefit_sponsorship)
      sign_in(user)
    end

    context '.close_extended_open_enrollment' do
      let(:benefit_application) { double }

      before do
        allow(benefit_applications).to receive(:find).and_return(benefit_application)
        allow(BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService).to receive_message_chain(:new,:end_open_enrollment).and_return(true)
      end

      it "renders index" do
        post :close_extended_open_enrollment

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(exchanges_hbx_profiles_root_path)
      end
    end
  end

  describe "benefit application creation" do
    let!(:user)                { FactoryBot.create(:user) }
    let!(:person)              { FactoryBot.create(:person, user: user) }
    let!(:permission)          { FactoryBot.create(:permission, :super_admin) }
    let!(:hbx_staff_role)      { FactoryBot.create(:hbx_staff_role, person: person, permission_id: permission.id, subrole: permission.name) }
    let!(:rating_area)         { FactoryBot.create_default :benefit_markets_locations_rating_area }
    let!(:service_area)        { FactoryBot.create_default :benefit_markets_locations_service_area }
    let!(:site)                { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    let!(:benefit_market)      { site.benefit_markets.first }
    let!(:organization)        { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
    let!(:employer_profile)    { organization.employer_profile }
    let!(:benefit_sponsorship) do
      bs = employer_profile.add_benefit_sponsorship
      bs.save!
      bs
    end
    let(:effective_period)     { (TimeKeeper.date_of_record + 3.months)..(TimeKeeper.date_of_record + 1.year + 3.months - 1.day) }
    let(:start_on)             { effective_period.min }
    let!(:issuer_profile)  { FactoryBot.create :benefit_sponsors_organizations_issuer_profile, assigned_site: site}
    let!(:current_benefit_market_catalog) do
      create(
        :benefit_markets_benefit_market_catalog,
        :with_product_packages,
        benefit_market: benefit_market,
        issuer_profile: issuer_profile,
        title: "SHOP Benefits for #{effective_period.min.year}",
        application_period: start_on.beginning_of_year..start_on.end_of_year
      )
    end

    let!(:valid_params)   do
      { admin_datatable_action: true,
        benefit_sponsorship_id: benefit_sponsorship.id.to_s,
        start_on: effective_period.min,
        end_on: effective_period.max,
        open_enrollment_start_on: TimeKeeper.date_of_record + 2.months,
        open_enrollment_end_on: TimeKeeper.date_of_record + 2.months + 20.day}
    end

    before :each do
      sign_in(user)
    end

    context 'viewing configuration tab' do
      before :each do
        get :configuration
      end

      it 'should respond with success status' do
        expect(response).to have_http_status(:success)
      end
    end

    context '.new_benefit_application' do
      before :each do
        get :new_benefit_application, params: { benefit_sponsorship_id: benefit_sponsorship.id.to_s}, xhr: true
      end

      it 'should respond with success status' do
        expect(response).to have_http_status(:success)
      end

      it 'should render new_benefit_application' do
        expect(response).to render_template("exchanges/hbx_profiles/new_benefit_application")
      end
    end

    context '.create_benefit_application when existing draft application' do
      before :each do
        valid_params["has_active_ba"] = false
        post :create_benefit_application, params: valid_params, xhr: true
      end

      it 'should respond with success status' do
        expect(response).to have_http_status(:success)
      end

      it 'should render new_benefit_application' do
        expect(response).to render_template("exchanges/hbx_profiles/create_benefit_application")
      end
    end

    context '.create_benefit_application when existing application is in active states' do
      before :each do
        valid_params["has_active_ba"] = true
        post :create_benefit_application, params: valid_params, xhr: true
      end

      it 'should respond with success status' do
        expect(response).to have_http_status(:success)
      end

      it 'should render new_benefit_application' do
        expect(response).to render_template("exchanges/hbx_profiles/create_benefit_application")
      end
    end

    context '.create_benefit_application when existing application is in termination_pending state' do
      let(:current_date) { TimeKeeper.date_of_record }
      let(:new_start_date) { (current_date + 2.months).beginning_of_month }

      let!(:term_bs) do
        FactoryBot.create(:benefit_sponsors_benefit_application,
                          :with_benefit_package,
                          :benefit_sponsorship => benefit_sponsorship,
                          :aasm_state => 'termination_pending',
                          :default_effective_period => current_date.beginning_of_year..current_date.end_of_month)
      end

      let(:required_params) do
        {
          admin_datatable_action: true,
          benefit_sponsorship_id: benefit_sponsorship.id.to_s,
          start_on: new_start_date,
          end_on: new_start_date + 1.year - 1.day,
          open_enrollment_start_on: (current_date + 1.month).beginning_of_month,
          open_enrollment_end_on: (current_date + 1.month).beginning_of_month + 20.days,
          has_active_ba: true
        }
      end

      before :each do
        post :create_benefit_application, params: required_params, xhr: true
      end

      it 'should respond with success status' do
        expect(response).to have_http_status(:success)
      end

      it 'should render new_benefit_application' do
        expect(response).to render_template("exchanges/hbx_profiles/create_benefit_application")
      end
    end
  end

  describe "GET edit_fein" do

    context "of an hbx super admin clicks Change FEIN" do
      let(:site) do
        FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca)
      end
      let(:employer_organization) do
        FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site).tap do |org|
          benefit_sponsorship = org.employer_profile.add_benefit_sponsorship
          benefit_sponsorship.save
        end
      end
      let(:person) do
        FactoryBot.create(:person, :with_hbx_staff_role).tap do |person|
          FactoryBot.create(:permission, :super_admin).tap do |permission|
            person.hbx_staff_role.update_attributes(permission_id: permission.id)
          end
        end
      end
      let(:user) do
        FactoryBot.create(:user, person: person)
      end
      let(:benefit_sponsorship) do
        employer_organization.benefit_sponsorships.first
      end

      it "renders edit_fein" do
        sign_in(user)
        @params = {id: benefit_sponsorship.id.to_s, employer_actions_id: "employer_actions_#{employer_organization.employer_profile.id}", :format => 'js'}
        get :edit_fein, params: @params, xhr: true
        expect(response).to render_template('edit_fein')
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "POST update_fein" do

    context "of an hbx super admin clicks Submit in Change FEIN window" do
      let(:site) do
        FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca)
      end
      let(:employer_organization) do
        FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site).tap do |org|
          benefit_sponsorship = org.employer_profile.add_benefit_sponsorship
          benefit_sponsorship.save
        end
      end
      let(:person) do
        FactoryBot.create(:person, :with_hbx_staff_role).tap do |person|
          FactoryBot.create(:permission, :super_admin).tap do |permission|
            person.hbx_staff_role.update_attributes(permission_id: permission.id)
          end
        end
      end
      let(:user) do
        FactoryBot.create(:user, person: person)
      end
      let(:benefit_sponsorship) do
        employer_organization.benefit_sponsorships.first
      end

      let(:new_valid_fein) { "23-4508390" }

      it "renders update_fein" do
        sign_in(user)
        @params = {:organizations_general_organization => {:new_fein => new_valid_fein}, :id => benefit_sponsorship.id.to_s, :employer_actions_id => "employer_actions_#{employer_organization.employer_profile.id}"}
        post :update_fein, params: @params, xhr: true
        # TODO: - benefit_sponsorship and benefit_market relationships are failing
        expect(response).to render_template('update_fein')
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "put mark_pvp_eligibilities" do
    let!(:site)          { FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :with_benefit_market_catalog_and_product_packages, :as_hbx_profile, Settings.site.key) }
    let(:catalog)        { site.benefit_markets[0].benefit_market_catalogs[0] }
    let(:product)        { catalog.product_packages[0].products.first }
    let(:rating_area)    { product.premium_tables.first.rating_area }

    let(:person) do
      FactoryBot.create(:person, :with_hbx_staff_role).tap do |person|
        FactoryBot.create(:permission, :super_admin).tap do |permission|
          person.hbx_staff_role.update_attributes(permission_id: permission.id)
        end
      end
    end

    let(:user) { FactoryBot.create(:user, person: person) }

    let(:pvp_active_areas) { { rating_area.id => "true" } }
    let(:valid_params) do
      { product_id: product.id, pvp_active_areas: pvp_active_areas }
    end

    context "when authorized user sign in" do
      before do
        sign_in user
        put :mark_pvp_eligibilities, params: valid_params
      end

      it "assigns the product" do
        expect(assigns(:product)).to eq(product)
      end

      it "redirects to the plan detailed page with success message" do
        expect(response).to redirect_to(plan_details_exchanges_hbx_profiles_path(year: product.active_year,
                                                                                 id: product.issuer_profile.organization.id,
                                                                                 product_id: product.id,
                                                                                 market: product.benefit_market_kind.to_s.split('_').last))
        expect(flash[:success]).to eq("Successfully marked premium value product(s)")
      end
    end

    context "premium value products got created with eligibility" do
      it "active eligibility is satisfied" do
        expect(product.premium_value_products.count).to eq 0
        sign_in user
        put :mark_pvp_eligibilities, params: valid_params
        expect(product.reload.premium_value_products.count).to eq 1
        pvp = product.premium_value_products.first
        expect(pvp.pvp_eligibilities.first.eligible?).to eq true
      end
    end

    context "when unauthorized user sign in" do
      before do
        person = FactoryBot.create(:person, :with_family)
        unauthorized_user = FactoryBot.create(:user, :person => person)
        sign_in(unauthorized_user)
      end

      it "should not allowed user to mark_pvp_eligibilities" do
        put :mark_pvp_eligibilities, params: valid_params
        expect(flash[:error]).to eq("You must be an HBX staff member")
      end
    end

    context "when marking eligibilities fails" do
      let(:invalid_params) do
        { product_id: product.id, pvp_active_areas: { BSON::ObjectId.new => "true" } }
      end

      before do
        sign_in user
        post :mark_pvp_eligibilities, params: invalid_params
      end

      it "redirects to the plan detailed page with failure message" do
        expect(response).to redirect_to(plan_details_exchanges_hbx_profiles_path(
                                          year: product.active_year,
                                          id: product.issuer_profile.organization.id,
                                          product_id: product.id,
                                          market: product.benefit_market_kind.to_s.split('_').last
                                        ))
        expect(flash[:failure]).to eq("Failed to mark premium value product(s)")
      end
    end
  end
end
