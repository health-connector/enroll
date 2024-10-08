# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe Insured::FamiliesController, dbclean: :after_each do
  context "set_current_user with no person" do
    let(:user) { FactoryBot.create(:user, person: person) }
    let(:person) { FactoryBot.create(:person) }

    before :each do
      sign_in user
    end

    it "should log the error" do
      expect(subject).to receive(:log) do |msg, severity|
        expect(severity[:severity]).to eq('error')
        expect(msg[:message]).to eq('@family was set to nil')
      end
      get :home
      expect(response).to redirect_to("/500.html")
    end

    it "should redirect" do
      get :home
      expect(response).to be_redirect
    end
  end

  context "set_current_user  as agent" do
    let(:user) { double("User", last_portal_visited: "test.com", id: 77, email: 'x@y.com', person: person) }
    let(:person) { FactoryBot.create(:person) }

    it "should raise the error on invalid person_id" do
      allow(session).to receive(:[]).and_return(33)
      allow(person).to receive(:agent?).and_return(true)
      expect{get :home}.to raise_error(ArgumentError)
    end
  end
end

RSpec.describe Insured::FamiliesController, dbclean: :after_each do

  let(:hbx_enrollments) { double("HbxEnrollment") }
  let(:user) { FactoryBot.create(:user) }
  let(:person) { double("Person", id: "test", addresses: [], no_dc_address: false, no_dc_address_reason: "", has_active_consumer_role?: false, has_active_employee_role?: true) }
  let(:family) { instance_double(Family, active_household: household, :model_name => "Family") }
  let(:household) { double("HouseHold", hbx_enrollments: hbx_enrollments) }
  let(:addresses) { [double] }
  let(:family_members) { [double("FamilyMember")] }
  let(:census_employee) { FactoryBot.create(:census_employee)}
  let(:employee_roles) { [double("EmployeeRole", :census_employee => census_employee)] }
  let(:resident_role) { FactoryBot.create(:resident_role) }
  let(:consumer_role) { double("ConsumerRole", bookmark_url: "/families/home") }
  # let(:coverage_wavied) { double("CoverageWavied") }
  let(:qle) { FactoryBot.create(:qualifying_life_event_kind, pre_event_sep_in_days: 30, post_event_sep_in_days: 0) }
  let(:sep) { double("SpecialEnrollmentPeriod") }


  before :each do
    allow(hbx_enrollments).to receive(:order).and_return(hbx_enrollments)
    allow(hbx_enrollments).to receive(:waived).and_return([])
    allow(hbx_enrollments).to receive(:any?).and_return(false)
    allow(hbx_enrollments).to receive(:non_external).and_return(hbx_enrollments)
    allow(user).to receive(:person).and_return(person)
    allow(user).to receive(:last_portal_visited).and_return("test.com")
    allow(person).to receive(:primary_family).and_return(family)
    allow(family).to receive_message_chain("family_members.active").and_return(family_members)
    allow(person).to receive(:consumer_role).and_return(consumer_role)
    allow(person).to receive(:active_employee_roles).and_return(employee_roles)
    allow(person).to receive(:has_active_resident_role?).and_return(true)
    allow(person).to receive(:resident_role).and_return(resident_role)
    allow(consumer_role).to receive(:bookmark_url=).and_return(true)
    sign_in(user)
  end

  describe "GET home" do
    let(:family_access_policy) { instance_double(FamilyPolicy, :show? => true) }

    before :each do
      allow(FamilyPolicy).to receive(:new).with(user, family).and_return(family_access_policy)
      allow(family).to receive(:enrollments).and_return(hbx_enrollments)
      allow(family).to receive(:enrollments_for_display).and_return(hbx_enrollments)
      allow(family).to receive(:waivers_for_display).and_return(hbx_enrollments)
      allow(family).to receive(:coverage_waived?).and_return(false)
      allow(family).to receive(:latest_active_sep).and_return sep
      allow(hbx_enrollments).to receive(:active).and_return(hbx_enrollments)
      allow(hbx_enrollments).to receive(:changing).and_return([])
      allow(user).to receive(:has_employee_role?).and_return(true)
      allow(user).to receive(:has_consumer_role?).and_return(true)
      allow(user).to receive(:last_portal_visited=).and_return("test.com")
      allow(user).to receive(:save).and_return(true)
      allow(user).to receive(:person).and_return(person)
      allow(person).to receive(:consumer_role).and_return(consumer_role)
      allow(person).to receive(:addresses).and_return(addresses)
      allow(person).to receive(:has_multiple_roles?).and_return(true)
      allow(consumer_role).to receive(:save!).and_return(true)

      allow(family).to receive(:_id).and_return(true)
      allow(hbx_enrollments).to receive(:_id).and_return(true)
      allow(hbx_enrollments).to receive(:each).and_return(hbx_enrollments)
      allow(hbx_enrollments).to receive(:reject).and_return(hbx_enrollments)
      allow(hbx_enrollments).to receive(:inject).and_return(hbx_enrollments)
      allow(hbx_enrollments).to receive(:compact).and_return(hbx_enrollments)

      session[:portal] = "insured/families"
    end

    context "#check_for_address_info" do
      before :each do
        allow(person).to receive(:user).and_return(user)
        allow(user).to receive(:identity_verified?).and_return(false)
        allow(person).to receive(:has_active_employee_role?).and_return(false)
        allow(person).to receive(:has_active_consumer_role?).and_return(true)
        allow(person).to receive(:active_employee_roles).and_return([])
        allow(person).to receive(:employee_roles).and_return([])
        allow(user).to receive(:get_announcements_by_roles_and_portal).and_return []
        allow(family).to receive(:check_for_consumer_role).and_return true
        allow(family).to receive(:active_family_members).and_return(family_members)
        sign_in user
      end

      it "should redirect to ridp page if user has not verified identity" do
        get :home
        expect(response).to redirect_to("/insured/consumer_role/ridp_agreement")
      end

      it "should redirect to edit page if user do not have addresses" do
        allow(person).to receive(:addresses).and_return []
        get :home
        expect(response).to redirect_to(edit_insured_consumer_role_path(consumer_role))
      end
    end



    context "#init_qle" do
      before :each do
        @controller = Insured::FamiliesController.new
        @qle = FactoryBot.create(:qualifying_life_event_kind)
        allow(@controller).to receive(:set_family)
        @controller.instance_variable_set(:@person, person)
        allow(person).to receive(:user).and_return(user)
        allow(user).to receive(:identity_verified?).and_return(false)
        allow(person).to receive(:has_active_employee_role?).and_return(true)
        allow(person).to receive(:has_active_consumer_role?).and_return(true)
        allow(person).to receive(:active_employee_roles).and_return([])
        allow(person).to receive(:employee_roles).and_return([])
        allow(user).to receive(:get_announcements_by_roles_and_portal).and_return []
        allow(family).to receive(:check_for_consumer_role).and_return true
        allow(family).to receive(:active_family_members).and_return(family_members)
        sign_in user
      end
      after do
        QualifyingLifeEventKind.destroy_all
      end

      it "should return qles" do
        allow(@controller).to receive(:params).and_return({})
        expect(@controller.instance_eval { init_qualifying_life_events }).to eq([@qle])
      end


      it "should return qles" do
        allow(@controller).to receive(:params).and_return({market: "individual_market_events"})
        expect(@controller.instance_eval { init_qualifying_life_events }).to eq([])
      end
    end

    context "for SHOP market", dbclean: :after_each do

      let(:employee_roles) { double }
      let(:employee_role) { FactoryBot.create(:employee_role, bookmark_url: "/families/home") }
      let(:census_employee) { FactoryBot.create(:census_employee, employee_role_id: employee_role.id) }

      before :each do
        FactoryBot.create(:announcement, content: "msg for Employee", audiences: ['Employee'])
        allow(person).to receive(:has_active_employee_role?).and_return(true)
        allow(person).to receive(:active_employee_roles).and_return([employee_role])
        allow(person).to receive(:employee_roles).and_return([employee_role])
        allow(family).to receive(:coverage_waived?).and_return(true)
        allow(family).to receive(:active_family_members).and_return(family_members)
        allow(family).to receive(:check_for_consumer_role).and_return nil
        allow(employee_role).to receive(:census_employee_id).and_return census_employee.id
        allow(controller).to receive(:authorize).and_return(true)
        sign_in user
        get :home
      end

      it "should be a success" do
        expect(response).to have_http_status(:success)
      end

      it "should render my account page" do
        expect(response).to render_template("home")
      end

      it "should assign variables" do
        expect(assigns(:qualifying_life_events)).to be_an_instance_of(Array)
        expect(assigns(:hbx_enrollments)).to eq(hbx_enrollments)
        expect(assigns(:employee_role)).to eq(employee_role)
      end

      it "should get shop market events" do
        expect(assigns(:qualifying_life_events)).to eq QualifyingLifeEventKind.shop_market_events
      end

      it "should get announcement" do
        expect(flash.now[:warning]).to eq ["msg for Employee"]
      end
    end

    context "for IVL market" do
      let(:user) { FactoryBot.create(:user) }
      let(:employee_roles) { double }

      before :each do
        allow(user).to receive(:idp_verified?).and_return true
        allow(user).to receive(:identity_verified?).and_return true
        allow(user).to receive(:last_portal_visited).and_return ''
        allow(person).to receive(:user).and_return(user)
        allow(person).to receive(:has_active_employee_role?).and_return(false)
        allow(person).to receive(:has_active_consumer_role?).and_return(true)
        allow(person).to receive(:active_employee_roles).and_return([])
        allow(person).to receive(:employee_roles).and_return(nil)
        allow(family).to receive(:active_family_members).and_return(family_members)
        allow(family).to receive(:check_for_consumer_role).and_return true
        sign_in user
        allow(controller).to receive(:authorize).and_return(true)
        get :home
      end

      it "should be a success" do
        expect(response).to have_http_status(:success)
      end

      it "should render my account page" do
        expect(response).to render_template("home")
      end

      it "should assign variables" do
        expect(assigns(:qualifying_life_events)).to be_an_instance_of(Array)
        expect(assigns(:hbx_enrollments)).to eq(hbx_enrollments)
        expect(assigns(:employee_role)).to be_nil
      end

      it "should get individual market events" do
        expect(assigns(:qualifying_life_events)).to eq QualifyingLifeEventKind.individual_market_events
      end

      context "who has not passed ridp" do
        let(:user) { double(identity_verified?: false, last_portal_visited: '', idp_verified?: false) }
        let(:user) { FactoryBot.create(:user) }

        before do
          allow(user).to receive(:idp_verified?).and_return false
          allow(user).to receive(:identity_verified?).and_return false
          allow(user).to receive(:last_portal_visited).and_return ''
          allow(person).to receive(:user).and_return(user)
          allow(person).to receive(:has_active_employee_role?).and_return(false)
          allow(person).to receive(:has_active_consumer_role?).and_return(true)
          allow(person).to receive(:active_employee_roles).and_return([])
          allow(controller).to receive(:authorize).and_return(true)
          sign_in user
          get :home
        end

        it "should be a redirect" do
          expect(response).to have_http_status(:redirect)
        end
      end
    end

    context "for both ivl and shop", dbclean: :after_each do
      include_context "setup benefit market with market catalogs and product packages"
      let!(:issuer_profile)  { FactoryBot.create :benefit_sponsors_organizations_issuer_profile, assigned_site: site}
      let!(:benefit_market_catalog) do
        create(
          :benefit_markets_benefit_market_catalog,
          :with_product_packages,
          benefit_market: benefit_market,
          issuer_profile: issuer_profile,
          title: "SHOP Benefits for #{current_effective_date.year}",
          application_period: (current_effective_date.prev_year.beginning_of_year..current_effective_date.prev_year.end_of_year)
        )
      end
      let!(:delete_dup) do
        BenefitMarkets::BenefitMarket.all.each do |benefit_market|
          benefit_market.destroy unless benefit_market.benefit_market_catalogs.present?
        end
      end
      include_context "setup initial benefit application"

      let!(:enrollments) {double}
      let!(:person2) {FactoryBot.create(:person, :with_consumer_role)}
      let!(:user2) {FactoryBot.create(:user, person: person2)}
      let!(:family2) {FactoryBot.create(:family, :with_primary_family_member, person: person2)}
      let!(:household) {family2.active_household}
      let!(:employee_role) {FactoryBot.create(:employee_role, person: person2, employer_profile: abc_profile, bookmark_url: "/families/home")}
      let!(:employee_role2) {FactoryBot.create(:employee_role, person: person2, bookmark_url: "/families/home")}
      let!(:census_employee) {FactoryBot.create(:census_employee, employee_role_id: employee_role2.id)}
      let(:family_access_policy) {instance_double(FamilyPolicy, :show? => true)}
      let(:display_hbx) do
        FactoryBot.create(:hbx_enrollment,
                          household: family2.latest_household,
                          coverage_kind: 'health',
                          effective_on: TimeKeeper.datetime_of_record,
                          enrollment_kind: 'open_enrollment',
                          kind: 'individual',
                          aasm_state: 'coverage_selected')
      end

      let(:waived_hbx) do
        FactoryBot.create(:hbx_enrollment,
                          household: family2.active_household,
                          kind: 'employer_sponsored',
                          effective_on: TimeKeeper.date_of_record,
                          aasm_state: 'inactive')
      end

      before :each do
        allow(FamilyPolicy).to receive(:new).with(user2, family2).and_return(family_access_policy)
        allow(user2).to receive(:has_employee_role?).and_return(true)
        allow(user2).to receive(:has_consumer_role?).and_return(true)
        allow(user2).to receive(:last_portal_visited=).and_return('test.com')
        allow(user2).to receive(:save).and_return(true)
        allow(user2).to receive(:person).and_return(person2)
        allow(person2).to receive(:has_active_consumer_role?).and_return(true)
        allow(family2).to receive(:coverage_waived?).and_return(true)
        allow(hbx_enrollments).to receive(:waived).and_return([waived_hbx])
        allow(enrollments).to receive(:non_external).and_return(enrollments)
        allow(family2).to receive(:enrollments).and_return(enrollments)
        allow(enrollments).to receive(:order).and_return([display_hbx])
        allow(family2).to receive(:check_for_consumer_role).and_return true
        allow(controller).to receive(:update_changing_hbxs).and_return(true)
        allow(employee_role).to receive(:census_employee_id).and_return census_employee.id
        allow(controller).to receive(:authorize).and_return(true)
        sign_in user2
      end

      context "with waived_hbx when display_hbx is employer_sponsored" do
        before :each do
          allow(family2).to receive(:active_family_members).and_return(family_members)
          get :home
        end

        it "should be a success" do
          expect(response).to have_http_status(:success)
        end

        it "should render my account page" do
          expect(response).to render_template("home")
        end

        it "should assign variables" do
          expect(assigns(:qualifying_life_events)).to be_an_instance_of(Array)
          expect(assigns(:hbx_enrollments)).to eq([display_hbx, waived_hbx])
          expect(assigns(:employee_role)).to eq(employee_role)
        end
      end

      context "with waived_hbx when display_hbx is individual" do
        before :each do
          allow(family2).to receive(:active_family_members).and_return(family_members)
          allow(employee_role).to receive(:census_employee_id).and_return census_employee.id
          get :home
        end

        it "should be a success" do
          expect(response).to have_http_status(:success)
        end

        it "should render my account page" do
          expect(response).to render_template("home")
        end

        it "should assign variables" do
          expect(assigns(:qualifying_life_events)).to be_an_instance_of(Array)
          expect(assigns(:hbx_enrollments)).to eq([display_hbx, waived_hbx])
          expect(assigns(:employee_role)).to eq(employee_role)
        end
      end
    end
  end

  describe "GET verification" do
    before :each do
      allow(controller).to receive(:authorize).and_return(true)
    end

    it "should be success" do
      get :verification
      expect(response).to have_http_status(:success)
    end

    it "renders verification template" do
      get :verification
      expect(response).to render_template("verification")
    end

    it "assign variables" do
      get :verification
      expect(assigns(:family_members)).to be_an_instance_of(Array)
      expect(assigns(:family_members)).to eq(family_members)
    end
  end

  describe "GET find_sep" do
    let(:user) { double(identity_verified?: true, idp_verified?: true) }
    let(:employee_roles) { double }
    let(:employee_role) { [double("EmployeeRole")] }
    let(:special_enrollment_period) {[double("SpecialEnrollmentPeriod")]}

    before :each do
      allow(person).to receive(:user).and_return(user)
      allow(person).to receive(:has_active_employee_role?).and_return(false)
      allow(person).to receive(:has_active_consumer_role?).and_return(true)
      allow(person).to receive(:has_multiple_roles?).and_return(true)
      allow(user).to receive(:has_hbx_staff_role?).and_return(false)
      allow(person).to receive(:active_employee_roles).and_return(employee_role)
      allow(family).to receive_message_chain("special_enrollment_periods.where").and_return([special_enrollment_period])
      allow(controller).to receive(:authorize).and_return(true)
      get :find_sep, params: { hbx_enrollment_id: "2312121212", change_plan: "change_plan" }
    end

    it "should be a redirect to edit insured person" do
      expect(response).to have_http_status(:redirect)
    end

    context "with a person with an address" do
      let(:person) { double("Person", id: "test", addresses: true, no_dc_address: false, no_dc_address_reason: "") }

      it "should be a success" do
        expect(response).to have_http_status(:success)
      end

      it "should render my account page" do
        expect(response).to render_template("find_sep")
      end

      it "should assign variables" do
        expect(assigns(:hbx_enrollment_id)).to eq("2312121212")
        expect(assigns(:change_plan)).to eq('change_plan')
      end
    end
  end

  describe "POST record_sep", dbclean: :after_each do

    before :each do
      EnrollRegistry[:continuous_plan_shopping].feature.stub(:is_enabled).and_return(false)
      date = TimeKeeper.date_of_record - 10.days
      @qle = FactoryBot.create(:qualifying_life_event_kind, :effective_on_event_date)
      @family = FactoryBot.build(:family, :with_primary_family_member)
      special_enrollment_period = @family.special_enrollment_periods.new(effective_on_kind: date)
      special_enrollment_period.selected_effective_on = date.strftime('%m/%d/%Y')
      special_enrollment_period.qualifying_life_event_kind = @qle
      special_enrollment_period.qle_on = date.strftime('%m/%d/%Y')
      special_enrollment_period.save
      allow(person).to receive(:primary_family).and_return(@family)
      allow(person).to receive(:hbx_staff_role).and_return(nil)
      allow(controller).to receive(:authorize).and_return(true)
    end

    context 'when its initial enrollment' do
      before :each do
        post :record_sep, params: { qle_id: @qle.id, qle_date: Date.today }
      end

      it "should redirect" do
        special_enrollment_period = @family.special_enrollment_periods.last
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(new_insured_group_selection_path({person_id: person.id, consumer_role_id: person.consumer_role.try(:id), enrollment_kind: 'sep', effective_on_date: special_enrollment_period.effective_on, qle_id: @qle.id}))
      end
    end

    context 'when its change of plan' do

      before :each do
        allow(@family).to receive(:enrolled_hbx_enrollments).and_return([double])
        post :record_sep, params: { qle_id: @qle.id, qle_date: Date.today }
      end

      it "should redirect with change_plan parameter" do
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(new_insured_group_selection_path({person_id: person.id, consumer_role_id: person.consumer_role.try(:id), change_plan: 'change_plan', enrollment_kind: 'sep', qle_id: @qle.id}))
      end
    end
  end

  describe "qle kinds" do
    before(:each) do
      allow(controller).to receive(:authorize).and_return(true)
      sign_in(user)
      @qle = FactoryBot.create(:qualifying_life_event_kind)
      @family = FactoryBot.build(:family, :with_primary_family_member)
      allow(person).to receive(:primary_family).and_return(@family)
      allow(person).to receive(:resident_role?).and_return(false)
    end

    context "#check_marriage_reason" do
      it "renders the check_marriage reason template" do
        get 'check_marriage_reason', params: { :date_val => (TimeKeeper.date_of_record - 10.days).strftime("%m/%d/%Y"), :qle_id => @qle.id}, xhr: true, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:check_marriage_reason)
        expect(assigns(:qle_date_calc)).to eq assigns(:qle_date) - Settings.aca.qle.with_in_sixty_days.days
      end
    end

    context "#check_move_reason" do
      it "renders the 'check_move_reason' template" do
        get 'check_move_reason', params: { :date_val => (TimeKeeper.date_of_record - 10.days).strftime("%m/%d/%Y"), :qle_id => @qle.id}, xhr: true, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:check_move_reason)
        expect(assigns(:qle_date_calc)).to eq assigns(:qle_date) - Settings.aca.qle.with_in_sixty_days.days
      end

      it "returns qualified_date as true" do
        get 'check_move_reason', params: { :date_val => (TimeKeeper.date_of_record - 10.days).strftime("%m/%d/%Y"), :qle_id => @qle.id}, xhr: true, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(assigns['qualified_date']).to eq(true)
      end

      it "returns qualified_date as false" do
        get 'check_move_reason', params: { :date_val => (TimeKeeper.date_of_record + 31.days).strftime("%m/%d/%Y"), :qle_id => @qle.id}, xhr: true, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(assigns['qualified_date']).to eq(false)
      end
    end

    context "#check_insurance_reason" do
      it "renders the 'check_insurance_reason' template" do
        get 'check_insurance_reason', params: { :date_val => (TimeKeeper.date_of_record - 10.days).strftime("%m/%d/%Y"), :qle_id => @qle.id}, xhr: true, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:check_insurance_reason)
      end

      it "returns qualified_date as true" do
        get 'check_insurance_reason', params: { :date_val => (TimeKeeper.date_of_record - 10.days).strftime("%m/%d/%Y"), :qle_id => @qle.id}, xhr: true, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(assigns['qualified_date']).to eq(true)
      end

      it "returns qualified_date as false" do
        get 'check_insurance_reason', params: { :date_val => (TimeKeeper.date_of_record + 31.days).strftime("%m/%d/%Y"), :qle_id => @qle.id}, xhr: true, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(assigns['qualified_date']).to eq(false)
      end
    end
  end

  describe "GET check_qle_date", dbclean: :after_each do

    before(:each) do
      allow(controller).to receive(:authorize).and_return(true)
      sign_in(user)
      allow(person).to receive(:resident_role?).and_return(false)
    end

    it "renders the 'check_qle_date' template" do
      get 'check_qle_date', params: { :date_val => (TimeKeeper.date_of_record - 10.days).strftime("%m/%d/%Y")}, xhr: true, :format => 'js'
      expect(response).to have_http_status(:success)
    end

    describe "with valid params" do
      it "returns qualified_date as true" do
        get 'check_qle_date', params: { :date_val => (TimeKeeper.date_of_record - 10.days).strftime("%m/%d/%Y")}, xhr: true, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(assigns['qualified_date']).to eq(true)
      end
    end

    describe "with invalid params" do

      it "returns qualified_date as false for invalid future date" do
        get 'check_qle_date', params: { :date_val => (TimeKeeper.date_of_record + 31.days).strftime("%m/%d/%Y")}, xhr: true, :format => 'js'
        expect(assigns['qualified_date']).to eq(false)
      end

      it "returns qualified_date as false for invalid past date" do
        get 'check_qle_date', params: { :date_val => (TimeKeeper.date_of_record - 61.days).strftime("%m/%d/%Y")}, xhr: true, :format => 'js'
        expect(assigns['qualified_date']).to eq(false)
      end
    end

    context "qle event when person has dual roles" do
      before :each do
        allow(person).to receive(:user).and_return(user)
        allow(person).to receive(:has_active_employee_role?).and_return(true)
        allow(person).to receive(:has_active_consumer_role?).and_return(true)
        @qle = FactoryBot.create(:qualifying_life_event_kind)
        @family = FactoryBot.build(:family, :with_primary_family_member)
        allow(person).to receive(:primary_family).and_return(@family)
      end

      it "future_qualified_date return true/false when qle market kind is shop" do
        date = TimeKeeper.date_of_record.strftime("%m/%d/%Y")
        get :check_qle_date, params: { date_val: date, qle_id: qle.id}, xhr: true, format: :js
        expect(response).to have_http_status(:success)
        expect(assigns(:future_qualified_date)).to eq(false)
      end

      it "future_qualified_date should return nil when qle market kind is indiviual" do
        qle = FactoryBot.build(:qualifying_life_event_kind, market_kind: "individual")
        allow(QualifyingLifeEventKind).to receive(:find).and_return(qle)
        date = TimeKeeper.date_of_record.strftime("%m/%d/%Y")
        get :check_qle_date, params: { date_val: date, qle_id: qle.id}, xhr: true, format: :js
        expect(response).to have_http_status(:success)
        expect(assigns(:qualified_date)).to eq true
        expect(assigns(:future_qualified_date)).to eq(nil)
      end
    end

    context "GET check_qle_date", dbclean: :after_each do
      include_context "setup benefit market with market catalogs and product packages"
      include_context "setup initial benefit application"

      let(:current_effective_date) { TimeKeeper.date_of_record.beginning_of_month }

      let!(:user) { FactoryBot.create(:user) }
      let!(:person1) { FactoryBot.create(:person) }
      let!(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person1) }

      let(:employee_role) {FactoryBot.create(:employee_role, person: person1, employer_profile: abc_profile)}
      let(:census_employee) { create(:census_employee, benefit_sponsorship: benefit_sponsorship, employer_profile: abc_profile) }

      before :each do
        allow(user).to receive(:person).and_return person1
        allow(person1).to receive(:primary_family).and_return family
        allow(employee_role).to receive(:census_employee).and_return census_employee
      end

      context "normal qle event" do
        it "should return true" do
          date = TimeKeeper.date_of_record.strftime("%m/%d/%Y")
          get :check_qle_date, params: { date_val: date}, xhr: true, format: :js
          expect(response).to have_http_status(:success)
          expect(assigns(:qualified_date)).to eq true
        end

        it "should return false" do
          sign_in user
          date = (TimeKeeper.date_of_record + 40.days).strftime("%m/%d/%Y")
          get :check_qle_date, params: { date_val: date}, xhr: true, format: :js
          expect(response).to have_http_status(:success)
          expect(assigns(:qualified_date)).to eq false
        end
      end

      context "special qle events which can not have future date" do
        subject { Observers::NoticeObserver.new }

        before(:each) do
          sign_in(user)
        end

        it "should return true" do
          date = (TimeKeeper.date_of_record + 8.days).strftime("%m/%d/%Y")
          get :check_qle_date, params: { date_val: date, qle_id: qle.id}, xhr: true, format: :js
          expect(response).to have_http_status(:success)
          expect(assigns(:qualified_date)).to eq true
        end

        it "should return false" do
          date = (TimeKeeper.date_of_record - 8.days).strftime("%m/%d/%Y")
          get :check_qle_date, params: { date_val: date, qle_id: qle.id}, xhr: true, format: :js
          expect(response).to have_http_status(:success)
          expect(assigns(:qualified_date)).to eq false
        end

        it "should return false and also notify sep request denied" do
          date = TimeKeeper.date_of_record.prev_month.strftime("%m/%d/%Y")
          get :check_qle_date, params: { qle_id: qle.id, date_val: date, qle_title: qle.title, qle_reporting_deadline: date, qle_event_on: date}, xhr: true, format: :js
          expect(assigns(:qualified_date)).to eq false

          expect(subject.notifier).to receive(:notify) do |event_name, payload|
            expect(event_name).to eq "acapi.info.events.employee.employee_notice_for_sep_denial"
            expect(payload[:event_object_kind]).to eq 'BenefitSponsors::BenefitApplications::BenefitApplication'
            expect(payload[:event_object_id]).to eq initial_application.id.to_s
            expect(payload[:notice_params][:qle_title]).to eq qle.title
            expect(payload[:notice_params][:qle_reporting_deadline]).to eq date
            expect(payload[:notice_params][:qle_event_on]).to eq date
          end
          subject.deliver(recipient: employee_role, event_object: initial_application, notice_event: "employee_notice_for_sep_denial", notice_params: {qle_title: qle.title, qle_reporting_deadline: date, qle_event_on: date})
        end

        it "should have effective_on_options" do
          date = (TimeKeeper.date_of_record - 8.days).strftime("%m/%d/%Y")
          effective_on_options = [TimeKeeper.date_of_record, TimeKeeper.date_of_record - 10.days]
          allow(QualifyingLifeEventKind).to receive(:find).and_return(qle)
          allow(qle).to receive(:is_dependent_loss_of_coverage?).and_return(true)
          allow(qle).to receive(:employee_gaining_medicare).and_return(effective_on_options)
          get :check_qle_date, params: { date_val: date, qle_id: qle.id}, xhr: true, format: :js
          expect(response).to have_http_status(:success)
          expect(assigns(:effective_on_options)).to eq effective_on_options
        end
      end
    end

    context "delete delete_consumer_broker" do
      let(:family) {FactoryBot.build(:family)}
      before :each do
        allow(person).to receive(:hbx_staff_role).and_return(double('hbx_staff_role', permission: double('permission',modify_family: true)))
        family.broker_agency_accounts = [
          FactoryBot.build(:broker_agency_account, family: family, employer_profile: nil)
        ]
        allow(Family).to receive(:find).and_return family
        delete :delete_consumer_broker, params: { :id => family.id }
      end

      it "should delete consumer broker" do
        expect(response).to have_http_status(:redirect)
        expect(family.current_broker_agency).to be nil
      end
    end
  end

  describe "GET upload_notice_form", dbclean: :after_each do
    let(:user) { FactoryBot.create(:user, person: person, roles: ["hbx_staff"]) }
    let(:person) { FactoryBot.create(:person) }

    before(:each) do
      allow(controller).to receive(:authorize).and_return(true)
      sign_in(user)
    end

    it "displays the upload_notice_form view" do
      get :upload_notice_form, xhr: true
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:upload_notice_form)
    end
  end

  describe "GET upload_notice", dbclean: :after_each do

    let(:consumer_role2) { FactoryBot.create(:consumer_role) }
    let(:person2) { FactoryBot.create(:person) }
    let(:user2) { FactoryBot.create(:user, person: person2, roles: ["hbx_staff"]) }
    let(:file) { fixture_file_upload("#{Rails.root}/spec/test_data/files/JavaScript.pdf", 'application/pdf')  }
    let(:temp_file) { double }
    let(:file_path) { File.dirname(__FILE__) }
    let(:bucket_name) { 'notices' }
    let(:doc_id) { "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket_name}#sample-key" }
    let(:subject) {"New Notice"}

    before(:each) do
      @controller = Insured::FamiliesController.new
      allow(temp_file).to receive(:path)
      allow(@controller).to receive(:set_family)
      @controller.instance_variable_set(:@person, person2)
      allow(@controller).to receive(:file_path).and_return(file_path)
      allow(@controller).to receive(:file_name).and_return("sample-filename")
      allow(@controller).to receive(:file_content_type).and_return("application/pdf")
      allow(Aws::S3Storage).to receive(:save).with(file_path, bucket_name).and_return(doc_id)
      person2.consumer_role = consumer_role2
      person2.consumer_role.gender = 'male'
      person2.save
      request.env["HTTP_REFERER"] = "/insured/families/upload_notice_form"
      allow(controller).to receive(:authorize).and_return(true)
      sign_in(user2)
    end

    it "when successful displays 'File Saved'" do
      post :upload_notice, params: { :file => file, :subject => subject}
      expect(flash[:notice]).to eq("File Saved")
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to request.env["HTTP_REFERER"]
    end

    it "when failure displays 'File not uploaded'" do
      post :upload_notice
      expect(flash[:error]).to eq("File or Subject not provided")
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to request.env["HTTP_REFERER"]
    end

    context "notice_upload_secure_message" do

      let(:notice) do
        Document.new({ title: "file_name", creator: "hbx_staff", subject: "notice", identifier: "urn:openhbx:terms:v1:file_storage:s3:bucket:#bucket_name#key",
                       format: "file_content_type" })
      end

      before do
        allow(@controller).to receive(:authorized_document_download_path).with("Person", person2.id, "documents", notice.id).and_return("/path/")
        @controller.send(:notice_upload_secure_message, notice, subject)
      end

      it "adds a message to person inbox" do
        expect(person2.inbox.messages.count).to eq(2) #1 welcome message, 1 upload notification
      end
    end

    context "notice_upload_email" do
      context "person has a consumer role" do
        context "person has chosen to receive electronic communication" do
          before do
            consumer_role2.contact_method = "Paper and Electronic communications"
          end

          it "sends the email" do
            expect(@controller.send(:notice_upload_email)).to be_a_kind_of(Mail::Message)
          end

        end

        context "person has chosen not to receive electronic communication" do
          before do
            consumer_role2.contact_method = "Only Paper communication"
          end

          it "should not sent the email" do
            expect(@controller.send(:notice_upload_email)).to be nil
          end
        end
      end

      context "person has a employee role" do
        let(:employee_role2) { FactoryBot.create(:employee_role) }

        before do
          person2.consumer_role = nil
          person2.employee_roles = [employee_role2]
          person2.save
        end

        context "person has chosen to receive electronic communication" do
          before do
            employee_role2.contact_method = "Paper and Electronic communications"
          end

          it "sends the email" do
            expect(@controller.send(:notice_upload_email)).to be_a_kind_of(Mail::Message)
          end

        end

        context "person has chosen not to receive electronic communication" do
          before do
            employee_role2.contact_method = "Only Paper communication"
          end

          it "should not sent the email" do
            expect(@controller.send(:notice_upload_email)).to be nil
          end
        end
      end
    end
  end

  context "GET manage_family, personal and inbox with auth", dbclean: :after_each do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"

    let(:current_effective_date) { TimeKeeper.date_of_record.beginning_of_month }

    let!(:user) { FactoryBot.create(:user) }
    let!(:person1) { FactoryBot.create(:person) }
    let!(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person1) }

    let(:employee_role) {FactoryBot.create(:employee_role, person: person1, employer_profile: abc_profile)}
    let(:census_employee) { create(:census_employee, benefit_sponsorship: benefit_sponsorship, employer_profile: abc_profile) }

    before :each do
      allow(user).to receive(:person).and_return person1
      allow(person1).to receive(:primary_family).and_return family
      allow(employee_role).to receive(:census_employee).and_return census_employee
    end

    context 'as a user not associated with the account' do
      let(:fake_person) { FactoryBot.create(:person, :with_employee_role) }
      let(:fake_user) { FactoryBot.create(:user, person: fake_person) }
      let!(:fake_family) { FactoryBot.create(:family, :with_primary_family_member, person: fake_person) }

      before do
        sign_in(fake_user)
      end

      it 'redirects the user to their own account on manage_family' do
        get :manage_family, params: { family: family.id }

        expect(response).to render_template("manage_family")
        expect(assigns(:family)).to eq(fake_family)
        expect(assigns(:qualifying_life_events)).to be_an_instance_of(Array)
        expect(assigns(:family_members)).to eq(fake_family.family_members)
      end

      it 'redirects the user to their own account on personal' do
        get :personal, params: { family: family.id }

        expect(response).to render_template("personal")
        expect(assigns(:family)).to eq(fake_family)
      end

      it 'redirects the user to their own account on inbox' do
        get :inbox, params: { family: family.id }

        expect(response).to render_template("inbox")
        expect(assigns(:family)).to eq(fake_family)
        expect(assigns(:folder)).to eq("Inbox")
      end
    end

    context 'as an admin' do
      let!(:admin_person) { FactoryBot.create(:person, :with_hbx_staff_role) }
      let!(:admin_user) { FactoryBot.create(:user, :with_hbx_staff_role, person: admin_person) }
      let!(:permission) { FactoryBot.create(:permission, :super_admin) }
      let!(:update_admin) { admin_person.hbx_staff_role.update_attributes(permission_id: permission.id) }

      before do
        sign_in(admin_user)
        session[:person_id] = person1.id
      end

      it 'should be a success on GET manage_family' do
        get :manage_family, params: { family: family.id }

        expect(response).to render_template("manage_family")
        expect(assigns(:family)).to eq(family)
        expect(assigns(:qualifying_life_events)).to be_an_instance_of(Array)
      end

      it 'should be a success on GET personal' do
        get :personal, params: { family: family.id }

        expect(response).to render_template("personal")
        expect(assigns(:family)).to eq(family)
      end

      it 'should be a success on GET inbox' do
        get :inbox, params: { family: family.id }

        expect(response).to render_template("inbox")
        expect(assigns(:family)).to eq(family)
        expect(assigns(:folder)).to eq("Inbox")
      end
    end

    context 'as broker' do
      let(:site)  { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
      let(:employer_organization)   { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
      let(:employer_profile) { employer_organization.profiles.first }
      let(:benefit_sponsorship) { FactoryBot.create(:benefit_sponsors_benefit_sponsorship, profile: employer_profile, benefit_market: site.benefit_markets.first) }
      let(:broker_agency_profile) { FactoryBot.create(:benefit_sponsors_organizations_broker_agency_profile, market_kind: 'shop', legal_name: 'Legal Name1', assigned_site: site) }
      let(:writing_agent) { FactoryBot.create(:broker_role, aasm_state: 'active', benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id) }
      let!(:broker_user) {FactoryBot.create(:user, :person => writing_agent.person, roles: ['broker_role', 'broker_agency_staff_role'])}
      let!(:broker_agency_account) { FactoryBot.create(:benefit_sponsors_accounts_broker_agency_account, benefit_sponsorship: benefit_sponsorship, broker_agency_profile: broker_agency_profile) }
      let!(:person2) { FactoryBot.create(:person) }
      let!(:family2) { FactoryBot.create(:family, :with_primary_family_member, person: person2) }
      let(:employee_role) { FactoryBot.create(:employee_role, person: person2, employer_profile: employer_profile, census_employee: census_employee)}
      let(:census_employee) { FactoryBot.create(:census_employee, :with_enrolled_census_employee, benefit_sponsorship_id: benefit_sponsorship.id) }

      context 'associated with the family' do
        before do
          allow(employee_role).to receive(:census_employee).and_return census_employee
          allow(person2).to receive(:active_employee_roles).and_return([employee_role])
          allow(controller).to receive(:authorize).and_return(true)
          sign_in(broker_user)
          session[:person_id] = person2.id
        end

        it 'should be a success on GET manage_family' do
          get :manage_family, params: { family: family2.id }

          expect(response).to have_http_status(:success)
          expect(response).to render_template("manage_family")
          expect(assigns(:family)).to eq(family2)
        end

        it 'should be a success on GET personal' do
          get :personal, params: { family: family2.id }

          expect(response).to have_http_status(:success)
          expect(response).to render_template("personal")
          expect(assigns(:family)).to eq(family2)
        end

        it 'should be a success on GET inbox' do
          get :inbox, params: { family: family2.id }

          expect(response).to have_http_status(:success)
          expect(response).to render_template("inbox")
          expect(assigns(:family)).to eq(family2)
        end
      end

      context 'not associated with the family' do
        before do
          session[:person_id] = person1.id
          sign_in(broker_user)
        end

        it 'should not be a success on GET manage_family' do
          get :manage_family, params: { family: family.id }

          expect(response).to have_http_status(:redirect)
          expect(response).to_not render_template("manage_family")
          expect(flash[:error]).to eq("Access not allowed for family_policy.manage_family?, (Pundit policy)")
        end

        it 'should not be a success on GET personal' do
          get :personal, params: { family: family.id }

          expect(response).to have_http_status(:redirect)
          expect(response).to_not render_template("personal")
          expect(flash[:error]).to eq("Access not allowed for family_policy.personal?, (Pundit policy)")
        end

        it 'should not be a success on GET inbox' do
          get :inbox, params: { family: family.id }

          expect(response).to have_http_status(:redirect)
          expect(response).to_not render_template("inbox")
          expect(flash[:error]).to eq("Access not allowed for family_policy.inbox?, (Pundit policy)")
        end
      end
    end
  end

  describe "logged in user has no roles" do
    shared_examples_for "logged in user has no authorization roles for families controller" do |action|
      it "redirects to root with flash message" do
        person = FactoryBot.create(:person, :with_family)
        unauthorized_user = FactoryBot.create(:user, :person => person)
        sign_in(unauthorized_user)

        get action
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("Access not allowed for family_policy.#{action}?, (Pundit policy)")
      end
    end

    it_behaves_like 'logged in user has no authorization roles for families controller', :home
    it_behaves_like 'logged in user has no authorization roles for families controller', :manage_family
    it_behaves_like 'logged in user has no authorization roles for families controller', :brokers
    it_behaves_like 'logged in user has no authorization roles for families controller', :find_sep
    it_behaves_like 'logged in user has no authorization roles for families controller', :personal
    it_behaves_like 'logged in user has no authorization roles for families controller', :inbox
    it_behaves_like 'logged in user has no authorization roles for families controller', :verification
    it_behaves_like 'logged in user has no authorization roles for families controller', :upload_application
    it_behaves_like 'logged in user has no authorization roles for families controller', :check_qle_date
    it_behaves_like 'logged in user has no authorization roles for families controller', :purchase
    it_behaves_like 'logged in user has no authorization roles for families controller', :upload_notice
    it_behaves_like 'logged in user has no authorization roles for families controller', :upload_notice_form
  end
end

RSpec.describe Insured::FamiliesController, dbclean: :after_each do
  describe "GET purchase" do
    let(:hbx_enrollment) { HbxEnrollment.new }
    let(:family) { FactoryBot.create(:family, :with_primary_family_member) }
    let(:person) { FactoryBot.create(:person) }
    let(:user) { FactoryBot.create(:user, person: person) }
    before :each do
      allow(HbxEnrollment).to receive(:find).and_return hbx_enrollment
      allow(person).to receive(:primary_family).and_return(family)
      allow(hbx_enrollment).to receive(:reset_dates_on_previously_covered_members).and_return(true)
      allow(controller).to receive(:authorize).and_return(true)
      sign_in(user)
      get :purchase, params: { id: family.id, hbx_enrollment_id: hbx_enrollment.id, terminate: 'terminate' }
    end

    it "should get hbx_enrollment" do
      expect(assigns(:enrollment)).to eq hbx_enrollment
    end

    it "should get terminate" do
      expect(assigns(:terminate)).to eq 'terminate'
    end
  end
end
