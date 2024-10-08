# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

module BenefitSponsors
  RSpec.describe Profiles::BrokerAgencies::BrokerAgencyProfilesController, type: :controller, dbclean: :after_each do

    routes { BenefitSponsors::Engine.routes }
    let!(:security_question)  { FactoryBot.create_default :security_question }

    let!(:user_with_hbx_staff_role) { FactoryBot.create(:user, :with_hbx_staff_role) }
    let!(:person) { FactoryBot.create(:person, user: user_with_hbx_staff_role) }
    let!(:person1) { FactoryBot.create(:person, :with_broker_role) }
    let!(:user_with_broker_role) { FactoryBot.create(:user, person: person1) }

    let!(:site)                          { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    let(:organization_with_hbx_profile)  { site.owner_organization }
    let!(:organization)                  { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_broker_agency_profile, site: site) }

    let!(:organization1)                 do
      org = FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_broker_agency_profile, site: site)
      org.broker_agency_profile.primary_broker_role = person1.broker_role
      org.save
      org
    end
    let!(:organization2)                 { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_broker_agency_profile, site: site) }
    let(:broker_agency1)                 { organization1.broker_agency_profile }
    let(:broker_agency2)                 { organization2.broker_agency_profile }

    let(:bap_id) { organization1.broker_agency_profile.id }
    let(:super_admin_permission) { FactoryBot.create(:permission, :super_admin) }
    let(:dev_permission) { FactoryBot.create(:permission, :developer) }

    let(:initialize_and_login_admin) do
      lambda { |permission|
        user_with_hbx_staff_role.person.build_hbx_staff_role(hbx_profile_id: organization_with_hbx_profile.hbx_profile.id, permission_id: permission.id)
        user_with_hbx_staff_role.person.hbx_staff_role.save!
        sign_in(user_with_hbx_staff_role)
      }
    end

    let(:initialize_and_login_broker) do
      lambda { |org|
        person1.broker_role.update_attributes!(benefit_sponsors_broker_agency_profile_id: org.broker_agency_profile.id, aasm_state: 'active')
        allow(user_with_broker_role).to receive(:has_broker_agency_staff_role?).and_return(true)
        person1.broker_agency_staff_roles.build(benefit_sponsors_broker_agency_profile_id: org.broker_agency_profile.id, aasm_state: 'active')
        person1.save!
        sign_in(user_with_broker_role)
      }
    end

    let(:initialize_and_login_broker_agency_staff) do
      lambda { |org|
        allow(user_with_broker_role).to receive(:has_broker_agency_staff_role?).and_return(true)
        person1.broker_agency_staff_roles.build(benefit_sponsors_broker_agency_profile_id: org.broker_agency_profile.id, aasm_state: 'active')
        person1.save!
        sign_in(user_with_broker_role)
      }
    end

    describe "for broker_agency_profile's index" do
      context "index for user with admin_role(on successful pundit)" do
        before :each do
          initialize_and_login_admin[super_admin_permission]
          get :index
        end

        it "should return http success" do
          expect(response).to have_http_status(:success)
        end

        it "should render the index template" do
          expect(response).to render_template("index")
        end
      end

      context "index for user with broker_role(on failed pundit)" do
        before :each do
          initialize_and_login_broker[organization1]
          allow(user_with_broker_role).to receive(:has_broker_agency_staff_role?).and_return(false)
          get :index
        end

        it "should not return success http status" do
          expect(response).not_to have_http_status(:success)
        end

        it "should rendirect to registration's new with broker_agency in params" do
          expect(response).to redirect_to(new_profiles_registration_path(profile_type: "broker_agency"))
        end
      end

      context "index for user with broker_agency_staff_role(on failed pundit)" do
        # let!(:broker_agency_staff_role) { FactoryBot.create(:broker_agency_staff_role, benefit_sponsors_broker_agency_profile_id: organization.broker_agency_profile.id, person: person1) }

        before :each do
          # user_with_broker_role.roles << "broker_agency_staff"
          # user_with_broker_role.save!
          # sign_in(user_with_broker_role)
          initialize_and_login_broker_agency_staff[organization1]
          get :index
        end

        it "should not return success http status" do
          expect(response).not_to have_http_status(:success)
        end

        it "should redirect to controller's show with broker_agency_profile's id" do
          expect(response).to redirect_to(profiles_broker_agencies_broker_agency_profile_path(:id => bap_id))
        end
      end
    end

    describe "for broker_agency_profile's show" do
      context "for show with a broker_agency_profile_id and with a valid user" do
        before :each do
          initialize_and_login_admin[super_admin_permission]
          allow(controller).to receive(:set_flash_by_announcement).and_return(true)
          get :show, params: { id: bap_id }
        end

        it "should return http success" do
          expect(response).to have_http_status(:success)
        end

        it "should render the index template" do
          expect(response).to render_template("show")
        end
      end

      context "for show with a broker_agency_profile_id and without a user" do
        before :each do
          get :show, params: { id: bap_id }
        end

        it "should not return success http status" do
          expect(response).not_to have_http_status(:success)
        end

        it "should redirect to the user's signup" do
          expect(response.location.include?('users/sign_up')).to be_truthy
        end
      end

      context 'for show with other broker_agency_profile_id and with a correct user' do
        let!(:organization1) {FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_broker_agency_profile, site: site)}
        let(:bap_id1) {organization1.broker_agency_profile.id}

        before :each do
          sign_in(user_with_broker_role)
          allow(controller).to receive(:set_flash_by_announcement).and_return(true)
          get :show, params: { id: bap_id1 }
        end

        it 'should not return success http status' do
          expect(response).to have_http_status(:redirect)
        end
      end
    end

    describe "for broker_agency_profile's family_index" do
      context "with a valid user and with broker_agency_profile_id(on successful pundit)" do
        before :each do
          initialize_and_login_admin[super_admin_permission]
          get :family_index, params: { id: bap_id }, xhr: true
        end

        it "should render family_index template" do
          expect(response).to render_template("benefit_sponsors/profiles/broker_agencies/broker_agency_profiles/family_index")
        end

        it "should return http success" do
          expect(response).to have_http_status(:success)
        end
      end

      context "with an invalid user and with broker_agency_profile_id(on falied pundit)" do
        let!(:user_without_person) { FactoryBot.create(:user, :with_hbx_staff_role) }

        before :each do
          sign_in(user_without_person)
          get :family_index, params: { id: bap_id }, xhr: true
        end

        it "should redirect to new of registration's controller for broker_agency" do
          expect(response).to redirect_to(new_profiles_registration_path(profile_type: "broker_agency"))
        end

        it "should not return success http status" do
          expect(response).not_to have_http_status(:success)
        end
      end
    end

    describe "for broker_agency_profile's staff_index" do
      context "with a valid user" do
        before :each do
          initialize_and_login_admin[super_admin_permission]
          get :staff_index, params: { id: bap_id }, xhr: true
        end

        it "should return success http status" do
          expect(response).to have_http_status(:success)
        end

        it "should render staff_index template" do
          expect(response).to render_template("benefit_sponsors/profiles/broker_agencies/broker_agency_profiles/staff_index")
        end
      end

      context 'with special chars in input' do
        before :each do
          initialize_and_login_admin[super_admin_permission]
          get :staff_index, params: { id: bap_id, page: '^[' }, xhr: true
        end

        it "should return success http status" do
          expect(response).to have_http_status(:success)
        end

        it "should render staff_index template" do
          expect(response).to render_template("benefit_sponsors/profiles/broker_agencies/broker_agency_profiles/staff_index")
        end
      end

      context 'with special chars in input' do
        before :each do
          initialize_and_login_admin[super_admin_permission]
          get :staff_index, params: { id: bap_id, page: '^[' }, xhr: true
        end

        it "should return success http status" do
          expect(response).to have_http_status(:success)
        end

        it "should render staff_index template" do
          expect(response).to render_template("benefit_sponsors/profiles/broker_agencies/broker_agency_profiles/staff_index")
        end
      end

      context "without a valid user" do
        let!(:user) { FactoryBot.create(:user, roles: [], person: FactoryBot.create(:person)) }

        before :each do
          sign_in(user)
          get :staff_index, params: { id: bap_id }, xhr: true
        end

        it "should not return success http status" do
          expect(response).not_to have_http_status(:success)
        end

        it "should redirect to new of registration's controller for broker_agency" do
          expect(response).to redirect_to(new_profiles_registration_path(profile_type: "broker_agency"))
        end
      end
    end

    describe "for broker_agency_profile's inbox" do

      let(:unread_messages) { person1.inbox.unread_messages }

      context "with a valid message" do
        before :each do
          person1.broker_role.update_attributes!(benefit_sponsors_broker_agency_profile_id: organization.broker_agency_profile.id)
          initialize_and_login_admin[super_admin_permission]
          get :inbox, params: { id: person1.id }, xhr: true
        end

        it "should return success http status" do
          expect(response).to have_http_status(:success)
        end

        it "should render inbox template" do
          expect(response).to render_template("benefit_sponsors/profiles/broker_agencies/broker_agency_profiles/inbox")
        end

        it "should have inbox messages" do
          person1.inbox.messages.first.update_attributes!(folder: 'inbox')
          expect(unread_messages.count).to eql(1)
        end
      end
    end

    describe "family_datatable" do
      include_context "setup benefit market with market catalogs and product packages"
      include_context "setup initial benefit application"
      include_context "setup employees with benefits"

      let!(:broker_agency_accounts) { FactoryBot.create(:benefit_sponsors_accounts_broker_agency_account, broker_agency_profile: organization.profiles.first, benefit_sponsorship: benefit_sponsorship) }
      let!(:user) { FactoryBot.create(:user, roles: [], person: FactoryBot.create(:person)) }
      let!(:ce) { benefit_sponsorship.census_employees.first }
      let!(:ee_person) { FactoryBot.create(:person, :with_employee_role, :with_family, first_name: ce.first_name, last_name: ce.last_name, dob: ce.dob, ssn: ce.ssn, gender: ce.gender) }

      context "should return sucess and family" do
        before :each do
          ce.employee_role_id = ee_person.employee_roles.first.id
          ce.save
          ee_person.employee_roles.first.census_employee_id = ce.id
          ee_person.save
          DataTablesInQuery = Struct.new(:draw, :skip, :take, :search_string)
          dt_query = DataTablesInQuery.new("1", 0, 10, "")
          initialize_and_login_admin[super_admin_permission]
          allow(controller).to receive(:extract_datatable_parameters).and_return(dt_query)
          get :family_datatable, params: { id: bap_id }, xhr: true
          @query = ::BenefitSponsors::Queries::BrokerFamiliesQuery.new(nil, organization.profiles.first.id, organization.profiles.first.market_kind)
        end

        it "should return a family" do
          expect(@query.total_count).not_to eq 0
        end

        it "should return success http status" do
          expect(response).to have_http_status(:success)
        end
      end

      context "should not return sucess" do
        before :each do
          sign_in(user)
          get :family_datatable, params: { id: bap_id }, xhr: true
        end

        it "should not return sucess http status" do
          expect(response).not_to have_http_status(:success)
        end
      end

      context "should not return family" do
        before :each do
          ce.employee_role_id = ee_person.employee_roles.first.id
          ce.save
          ee_person.employee_roles.first.census_employee_id = ce.id
          ee_person.save
          benefit_sponsorship.broker_agency_accounts.first.update_attributes(is_active: false)
          DataTablesInQuery = Struct.new(:draw, :skip, :take, :search_string)
          dt_query = DataTablesInQuery.new("1", 0, 10, "")
          initialize_and_login_admin[super_admin_permission]
          allow(controller).to receive(:extract_datatable_parameters).and_return(dt_query)
          get :family_datatable, params: { id: bap_id }, xhr: true
          @query = ::BenefitSponsors::Queries::BrokerFamiliesQuery.new(nil, organization.profiles.first.id, organization.profiles.first.market_kind)
        end

        it "should not return family" do
          expect(@query.total_count).to eq 0
        end
      end

      context "should return family when search by persons name" do
        before :each do
          ce.employee_role_id = ee_person.employee_roles.first.id
          ce.save
          ee_person.employee_roles.first.census_employee_id = ce.id
          ee_person.save
          dt_query = OpenStruct.new({ :draw => 1, :skip => 0, :take => 10, :search_string => "" })
          initialize_and_login_admin[super_admin_permission]
          Person.create_indexes
          allow(controller).to receive(:extract_datatable_parameters).and_return(dt_query)
          get :family_datatable, params: { id: bap_id }, xhr: true
          @query = ::BenefitSponsors::Queries::BrokerFamiliesQuery.new(ee_person.first_name, organization.profiles.first.id, organization.profiles.first.market_kind)
        end

        it "should return a family" do
          expect(@query.filtered_count).not_to eq 0
        end

        it "should return success http status" do
          expect(response).to have_http_status(:success)
        end
      end

      context "should not return family when search incorrect name" do
        before :each do
          ce.employee_role_id = ee_person.employee_roles.first.id
          ce.save
          ee_person.employee_roles.first.census_employee_id = ce.id
          ee_person.save
          dt_query = OpenStruct.new({ :draw => 1, :skip => 0, :take => 10, :search_string => "" })
          Person.create_indexes
          initialize_and_login_admin[super_admin_permission]
          allow(controller).to receive(:extract_datatable_parameters).and_return(dt_query)
          get :family_datatable, params: { id: bap_id }, xhr: true
          @query = ::BenefitSponsors::Queries::BrokerFamiliesQuery.new("test", organization.profiles.first.id, organization.profiles.first.market_kind)
        end

        it "should return a family" do
          expect(@query.filtered_count).to eq 0
        end

        it "should return success http status" do
          expect(response).to have_http_status(:success)
        end
      end
    end

    describe "#commission_statements" do
      context "admin" do
        context "with the correct permissions" do
          before :each do
            initialize_and_login_admin[super_admin_permission]
            get :commission_statements, params: { id: bap_id }, xhr: true
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end

          it "should render the commission_statements template" do
            expect(response).to render_template("commission_statements")
          end
        end

        context "with the incorrect permissions" do
          let!(:permission) { FactoryBot.create(:permission, :developer) }

          before :each do
            initialize_and_login_admin[dev_permission]
            get :commission_statements, params: { id: bap_id }, xhr: true
          end

          it "should redirect to new of registration's controller for broker_agency" do
            expect(response).to redirect_to(new_profiles_registration_path(profile_type: "broker_agency"))
          end

          it "should not render the commission_statements template" do
            expect(response).to_not render_template("commission_statements")
          end
        end
      end

      context "broker" do
        context 'in the agency' do
          before :each do
            initialize_and_login_broker[organization1]
            get :commission_statements, params: { id: bap_id }, xhr: true
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end

          it "should render the commission_statements template" do
            expect(response).to render_template("commission_statements")
          end
        end

        context 'not in the agency' do
          before :each do

            initialize_and_login_broker[organization2]
            get :commission_statements, params: { id: bap_id }, xhr: true
          end

          it "should redirect to the broker agency profile page path" do
            profile_page = profiles_broker_agencies_broker_agency_profile_path(:id => broker_agency2.id)
            expect(response).to redirect_to(profile_page)
          end

          it "should not render the commission_statements template" do
            expect(response).to_not render_template("commission_statements")
          end
        end
      end

      context "broker staff" do
        context 'in the agency' do
          before :each do
            initialize_and_login_broker_agency_staff[organization1]
            get :commission_statements, params: { id: bap_id }, xhr: true
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end

          it "should not render the commission_statements template" do
            expect(response).to render_template("commission_statements")
          end
        end

        context 'not in the agency' do
          before :each do
            initialize_and_login_broker_agency_staff[organization2]
            get :commission_statements, params: { id: bap_id }, xhr: true
          end

          it "should redirect to the broker agency profile page path" do
            profile_page = profiles_broker_agencies_broker_agency_profile_path(:id => broker_agency2.id)
            expect(response).to redirect_to(profile_page)
          end

          it "should not render the commission_statements template" do
            expect(response).to_not render_template("commission_statements")
          end
        end
      end
    end

    describe "#show_commission_statement" do
      let(:document) { broker_agency1.documents.create(title: 'TEST', identifier: '38470295384759384752') }

      before do
        s3_object = instance_double(Aws::S3Storage)
        allow(Aws::S3Storage).to receive(:find).with(document.identifier).and_return(s3_object)
      end

      context "admin" do
        context "with the correct permissions" do
          before :each do
            initialize_and_login_admin[super_admin_permission]
            get :show_commission_statement, params: { id: bap_id, statement_id: document.id }, xhr: true
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end
        end

        context "with the incorrect permissions" do
          let!(:permission) { FactoryBot.create(:permission, :developer) }

          before :each do
            initialize_and_login_admin[dev_permission]
            get :show_commission_statement, params: { id: bap_id, statement_id: document.id }, xhr: true
          end

          it "should redirect to new of registration's controller for broker_agency" do
            expect(response).to redirect_to(new_profiles_registration_path(profile_type: "broker_agency"))
          end
        end
      end

      context "broker" do
        context 'in the agency' do
          before :each do
            initialize_and_login_broker[organization1]
            get :show_commission_statement, params: { id: bap_id, statement_id: document.id }, xhr: true
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end
        end

        context 'not in the agency' do
          before :each do
            initialize_and_login_broker[organization2]
            get :show_commission_statement, params: { id: bap_id, statement_id: document.id }, xhr: true
          end

          it "should redirect to the broker agency profile page path" do
            profile_page = profiles_broker_agencies_broker_agency_profile_path(:id => broker_agency2.id)
            expect(response).to redirect_to(profile_page)
          end
        end
      end

      context "broker staff" do
        context 'in the agency' do
          before :each do
            initialize_and_login_broker_agency_staff[organization1]
            get :show_commission_statement, params: { id: bap_id, statement_id: document.id }, xhr: true
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end
        end

        context 'not in the agency' do
          before :each do
            initialize_and_login_broker_agency_staff[organization2]
            get :show_commission_statement, params: { id: bap_id, statement_id: document.id }, xhr: true
          end

          it "should redirect to the broker agency profile page path" do
            profile_page = profiles_broker_agencies_broker_agency_profile_path(:id => broker_agency2.id)
            expect(response).to redirect_to(profile_page)
          end
        end
      end
    end

    describe "#download_commission_statement" do
      let(:document) { broker_agency1.documents.create(title: 'TEST', identifier: '38470295384759384752') }

      before do
        s3_object = instance_double(Aws::S3Storage)
        allow(Aws::S3Storage).to receive(:find).with(document.identifier).and_return(s3_object)
      end

      context "admin" do
        context "with the correct permissions" do
          before :each do
            initialize_and_login_admin[super_admin_permission]
            get :download_commission_statement, params: { id: bap_id, statement_id: document.id }, xhr: true
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end
        end

        context "with the incorrect permissions" do
          let!(:permission) { FactoryBot.create(:permission, :developer) }

          before :each do
            initialize_and_login_admin[dev_permission]
            get :download_commission_statement, params: { id: bap_id, statement_id: document.id }, xhr: true
          end

          it "should redirect to new of registration's controller for broker_agency" do
            expect(response).to redirect_to(new_profiles_registration_path(profile_type: "broker_agency"))
          end
        end
      end

      context "broker" do
        context 'in the agency' do
          before :each do
            initialize_and_login_broker[organization1]
            get :download_commission_statement, params: { id: bap_id, statement_id: document.id }, xhr: true
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end
        end

        context 'not in the agency' do
          before :each do
            initialize_and_login_broker[organization2]
            get :download_commission_statement, params: { id: bap_id, statement_id: document.id }, xhr: true
          end

          it "should redirect to the broker agency profile page path" do
            profile_page = profiles_broker_agencies_broker_agency_profile_path(:id => broker_agency2.id)
            expect(response).to redirect_to(profile_page)
          end
        end
      end

      context "broker staff" do
        context 'in the agency' do
          before :each do
            initialize_and_login_broker_agency_staff[organization1]
            get :download_commission_statement, params: { id: bap_id, statement_id: document.id }, xhr: true
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end
        end

        context 'not in the agency' do
          before :each do
            initialize_and_login_broker_agency_staff[organization2]
            get :download_commission_statement, params: { id: bap_id, statement_id: document.id }, xhr: true
          end

          it "should redirect to the broker agency profile page path" do
            profile_page = profiles_broker_agencies_broker_agency_profile_path(:id => broker_agency2.id)
            expect(response).to redirect_to(profile_page)
          end
        end
      end
    end

    describe "#messages" do
      context "admin" do
        context "with the correct permissions" do
          before :each do
            initialize_and_login_admin[super_admin_permission]
            get :messages, params: { id: bap_id }, xhr: true
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end

          it "should render the messages template" do
            expect(response).to render_template("messages")
          end
        end

        context "with the incorrect permissions" do
          let!(:permission) { FactoryBot.create(:permission, :developer) }

          before :each do
            initialize_and_login_admin[dev_permission]
            get :messages, params: { id: bap_id }, xhr: true
          end

          it "should redirect to new of registration's controller for broker_agency" do
            expect(response).to redirect_to(new_profiles_registration_path(profile_type: "broker_agency"))
          end

          it "should not render the messages template" do
            expect(response).to_not render_template("messages")
          end
        end
      end

      context "broker" do
        context 'in the agency' do
          before :each do
            initialize_and_login_broker[organization1]
            get :messages, params: { id: bap_id }, xhr: true
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end

          it "should not render the messages template" do
            expect(response).to render_template("messages")
          end
        end

        context 'not in the agency' do
          before :each do
            initialize_and_login_broker[organization2]
            get :messages, params: { id: bap_id }, xhr: true
          end

          it "should redirect to the profile page of their broker agency" do
            profile_page = profiles_broker_agencies_broker_agency_profile_path(:id => broker_agency2.id)
            expect(response).to redirect_to(profile_page)
          end

          it "should not render the messages template" do
            expect(response).to_not render_template("messages")
          end
        end
      end

      context "broker staff" do
        context 'in the agency' do
          before :each do
            initialize_and_login_broker_agency_staff[organization1]
            get :messages, params: { id: bap_id }, xhr: true
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end

          it "should not render the messages template" do
            expect(response).to render_template("messages")
          end
        end

        context 'not in the agency' do
          before :each do
            initialize_and_login_broker_agency_staff[organization2]
            get :messages, params: { id: bap_id }, xhr: true
          end

          it "should redirect to the profile page of their broker agency" do
            profile_page = profiles_broker_agencies_broker_agency_profile_path(:id => broker_agency2.id)
            expect(response).to redirect_to(profile_page)
          end

          it "should not render the messages template" do
            expect(response).to_not render_template("messages")
          end
        end
      end
    end
  end
end
