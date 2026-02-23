require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

module BenefitSponsors
  RSpec.describe Profiles::Employers::EmployerProfilesController, type: :controller, dbclean: :after_each do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"

    let(:profile) { benefit_sponsorship.organization.profiles.first }
    let(:employer_staff_person) { create(:person) }
    let(:employer_staff_user) { create(:user, person: employer_staff_person) }
    let(:er_staff_role) { create(:benefit_sponsor_employer_staff_role, benefit_sponsor_employer_profile_id: benefit_sponsorship.organization.employer_profile.id) }
    let(:broker_agency_profile) { create(:benefit_sponsors_organizations_broker_agency_profile, market_kind: :shop) }
    let(:broker_role) { create(:broker_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: :active) }
    let!(:broker_role_user) { create(:user, person: broker_role.person, roles: ['broker_role']) }

    # broker staff role
    let(:broker_agency_staff_role) { create(:broker_agency_staff_role, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, aasm_state: 'active') }
    let!(:broker_agency_staff_user) { create(:user, person: broker_agency_staff_role.person, roles: ['broker_agency_staff_role']) }

    routes { BenefitSponsors::Engine.routes }
    let!(:security_question)  { FactoryBot.create_default :security_question }

    let(:person) { FactoryBot.create(:person) }
    let(:user) { FactoryBot.create(:user, :person => person)}

    let!(:site)                  { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    let!(:benefit_sponsor)       { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
    let(:employer_profile)      { benefit_sponsor.employer_profile }
    let!(:rating_area)           { FactoryBot.create_default :benefit_markets_locations_rating_area }
    let!(:service_area)          { FactoryBot.create_default :benefit_markets_locations_service_area }
    let(:benefit_sponsorship) do
      sponsorship = employer_profile.add_benefit_sponsorship
      sponsorship.save
      sponsorship
    end

    before do
      controller.prepend_view_path("../../app/views")
      person.employer_staff_roles.create! benefit_sponsor_employer_profile_id: employer_profile.id
    end

    describe "POST employee_bulk_upload" do
      before do
        sign_in user
        post :bulk_employee_upload, params: { employer_profile_id: benefit_sponsor.profiles.first.id }
      end

      it "displays an error for a missing file" do
        expect(assigns(:roster_upload_form).errors[:base].first).to eq "File is missing"
      end
    end

    describe "GET show_pending" do
      before do
        sign_in user
        get :show_pending
      end

      it "should render show template" do
        expect(response).to render_template("show_pending")
      end

      it "should return http success" do
        expect(response).to have_http_status(:success)
      end
    end

    describe "GET show" do
      let!(:employees) do
        FactoryBot.create_list(:census_employee, 2, employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship)
      end

      context "tab: employees" do
        before do
          benefit_sponsorship.save!
          allow(controller).to receive(:authorize).and_return(true)
          sign_in user
          get :show, params: { id: benefit_sponsor.profiles.first.id.to_s, tab: 'employees' }
          allow(employer_profile).to receive(:active_benefit_sponsorship).and_return benefit_sponsorship
        end

        it "should render show template" do
          expect(response).to render_template("show")
        end

        it "should return http success" do
          expect(response).to have_http_status(:success)
        end
      end

      context "tab: accounts" do
        before do
          benefit_sponsorship.save!
          allow(controller).to receive(:authorize).and_return(true)
          sign_in user
          get :show, params: { id: benefit_sponsor.profiles.first.id, tab: 'accounts' }
          allow(employer_profile).to receive(:active_benefit_sponsorship).and_return benefit_sponsorship
        end

        it "should render show template" do
          expect(response).to render_template("show")
        end

        it "should return http success" do
          expect(response).to have_http_status(:success)
        end
      end

      context "tab: families" do
        let(:person) {FactoryBot.create(:person)}
        let(:employee_role1) {FactoryBot.create(:benefit_sponsors_employee_role, person: person, employer_profile: employer_profile, benefit_sponsors_employer_profile_id: employer_profile.id)}
        let(:census_employee) do
          census_employee = FactoryBot.create(:census_employee, :with_active_assignment,
                                              first_name: person.first_name,
                                              last_name: person.last_name,
                                              benefit_sponsorship: benefit_sponsorship,
                                              employer_profile: benefit_sponsorship.profile,
                                              benefit_group: current_benefit_package,
                                              employee_role_id: employee_role1.id)
          census_employee.update_attributes(ssn: person.ssn, dob: person.dob)
          employee_role1.update_attributes(census_employee_id: census_employee.id)
          census_employee
        end

        before do
          allow(person).to receive(:active_employee_roles).and_return [employee_role1]
          allow(employee_role1).to receive(:census_employee).and_return census_employee
          benefit_sponsorship.save!
          allow(controller).to receive(:authorize).and_return(true)
          sign_in user
          get :show, params: {id: benefit_sponsor.profiles.first.id.to_s, tab: 'families'}
          allow(employer_profile).to receive(:active_benefit_sponsorship).and_return benefit_sponsorship
        end

        it "should render show template" do
          expect(response).to render_template("show")
        end

        it "should return http success" do
          expect(response).to have_http_status(:success)
        end

        it "should return valid families" do
          expect(assigns(:employees)).to eq([employee_role1])
          expect(response).to render_template("show")
        end
      end
    end


    describe "GET coverage_reports" do
      context "without today's date billing_date param" do
        let!(:employees) do
          FactoryBot.create_list(:census_employee, 2, employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship)
        end

        before do
          benefit_sponsorship.save!
          allow(controller).to receive(:authorize).and_return(true)
          sign_in user
          get :coverage_reports, params: { employer_profile_id: benefit_sponsor.profiles.first.id, billing_date: TimeKeeper.date_of_record.next_month.beginning_of_month.strftime("%m/%d/%Y") }
          allow(employer_profile).to receive(:active_benefit_sponsorship).and_return benefit_sponsorship
        end

        it "should render coverage_reports template" do
          expect(response).to render_template("coverage_reports")
        end

        it "should return http success" do
          expect(response).to have_http_status(:success)
        end

        it "uses the default billing date" do
          datatable = assigns(:datatable)

          expect(:billing_date).to be_present
          expect(datatable).to be_a(Effective::Datatables::BenefitSponsorsCoverageReportsDataTable)
          expect(datatable.attributes[:billing_date].strftime("%m/%d/%Y")).to eq(TimeKeeper.date_of_record.next_month.beginning_of_month.strftime("%m/%d/%Y"))
        end
      end

      context "with billing_date parameter" do
        let(:selected_date) { "2025-10-01" }
        let(:parsed_date) { Date.parse(selected_date) }

        before do
          benefit_sponsorship.save!
          allow(controller).to receive(:authorize).and_return(true)
          sign_in user
          get :coverage_reports, params: { employer_profile_id: employer_profile.id, billing_date: selected_date }
          allow(employer_profile).to receive(:active_benefit_sponsorship).and_return benefit_sponsorship
          allow(DateParser).to receive(:smart_parse).with(selected_date).and_return(parsed_date)
        end

        it "parses and uses the provided billing date" do
          get :coverage_reports, params: { employer_profile_id: employer_profile.id, billing_date: selected_date }

          expect(response).to have_http_status(:success)
          expect(DateParser).to have_received(:smart_parse).with(selected_date)
          expect(assigns(:billing_date)).to eq(parsed_date)
        end

        it "passes billing_date to the datatable" do
          get :coverage_reports, params: { employer_profile_id: employer_profile.id, billing_date: selected_date }

          datatable = assigns(:datatable)
          expect(datatable.attributes[:billing_date]).to eq(parsed_date)
        end
      end
    end

    describe "POST estimate_cost" do
      let!(:employees) { FactoryBot.create_list(:census_employee, 2, employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship)}

      context "with an active user" do
        before do
          sign_in user
          post :estimate_cost, params: { employer_profile_id: benefit_sponsor.profiles.first.id, benefit_package_id: BSON::ObjectId.new }
          allow(employer_profile).to receive(:active_benefit_sponsorship).and_return benefit_sponsorship
        end

        it "should return http success" do
          expect(response).to have_http_status(:success)
        end
      end

      context "without POC role" do
        before do
          sign_in employer_staff_user
        end

        it "denies access to the estimate_cost for the current user" do
          post :estimate_cost, params: { employer_profile_id: employer_profile.id, benefit_package_id: BSON::ObjectId.new }

          expect(flash[:error]).to eq("Access not allowed for estimate_cost?, (Pundit policy)")
        end
      end

      context "with an inactive broker role" do
        before do
          broker_role.update!(aasm_state: 'inactive')
          sign_in broker_role_user
        end

        it "denies access to the estimate_cost for the broker" do
          post :estimate_cost, params: { employer_profile_id: employer_profile.id, benefit_package_id: BSON::ObjectId.new }

          expect(flash[:error]).to eq("Access not allowed for estimate_cost?, (Pundit policy)")
        end
      end
    end

    describe "GET download_invoice and show_invoice" do
      let(:initial_invoice) do
        employer_profile.documents.new({ title: "SomeTitle",
                                         date: TimeKeeper.date_of_record,
                                         creator: "hbx_staff",
                                         subject: "initial_invoice",
                                         identifier: "urn:openhbx:terms:v1:file_storage:s3:bucket:#bucket_name#key",
                                         format: "file_content_type"})
      end

      before do
        initial_invoice.save!
        employer_profile.documents << initial_invoice
        employer_profile.save!
      end

      shared_examples_for "logged in user has no authorization roles for EmployerProfilesController" do |action, action_type|
        it "displays an error message" do
          sign_in employer_staff_user

          get action, params: {invoice_id: initial_invoice.id, id: employer_profile.id}

          expect(flash[:error]).to eq("Access not allowed for #{action_type}, (Pundit policy)")
        end
      end

      it_behaves_like 'logged in user has no authorization roles for EmployerProfilesController', :download_invoice, "download_invoice?"
      it_behaves_like 'logged in user has no authorization roles for EmployerProfilesController', :show_invoice, "show_invoice?"
    end

    describe "GET run_eligibility_check" do
      let(:admin_user) { FactoryBot.create(:user, :with_hbx_staff_role, :person => person)}
      let!(:employees) { FactoryBot.create_list(:census_employee, 2, employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship)}
      let(:business_policy) { instance_double("some_policy", success_results: { business_rule: "validated successfully" })}

      before do
        sign_in admin_user
        allow(subject).to receive(:business_policy_for).and_return(business_policy)
        allow(business_policy).to receive(:is_satisfied?).and_return(true)
        get :run_eligibility_check, params: { employer_profile_id: benefit_sponsor.profiles.first.id }
        allow(employer_profile).to receive(:active_benefit_sponsorship).and_return benefit_sponsorship
      end

      it "should return http success" do
        expect(response).to have_http_status(:success)
      end

      it 'responds with a json content type' do
        expect(response.content_type).to include('application/json')
        expect(JSON.parse(response.body, symoblize_names: true)).to include("business_rule" => "validated successfully")
      end
    end

    describe "GET export_census_employees", dbclean: :after_each do
      include_context "setup benefit market with market catalogs and product packages"
      include_context "setup initial benefit application"

      let(:admin_user) { FactoryBot.create(:user, :with_hbx_staff_role, :person => person)}
      let(:employer_profile) { abc_profile }
      let!(:employees) do
        FactoryBot.create_list(:census_employee, 2, employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship)
      end
      let(:employee_ssn) { SymmetricEncryption.decrypt(employees.first.encrypted_ssn) }

      it "should export cvs" do
        sign_in(admin_user)
        get :export_census_employees, params: {employer_profile_id: employer_profile}, format: :csv
        expect(response).to have_http_status(:success)
        expect(response).not_to have_content("SSN")
        expect(response).not_to have_content(employee_ssn)
      end
    end
  end
end
