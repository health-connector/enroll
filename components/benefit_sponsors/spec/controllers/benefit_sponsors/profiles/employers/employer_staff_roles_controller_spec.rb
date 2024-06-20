# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

module BenefitSponsors
  RSpec.describe Profiles::Employers::EmployerStaffRolesController, type: :controller, dbclean: :after_each do
    before :all do
      DatabaseCleaner.clean
    end

    routes { BenefitSponsors::Engine.routes }
    let!(:security_question)  { FactoryBot.create_default :security_question }

    let(:staff_class) { BenefitSponsors::Organizations::OrganizationForms::StaffRoleForm }

    let(:site)            { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    let(:benefit_market)  { site.benefit_markets.first }

    let(:benefit_sponsor)     { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
    let(:new_benefit_sponsor) { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
    let(:employer_profile)    { benefit_sponsor.employer_profile }

    let!(:active_employer_staff_role) { FactoryBot.build(:benefit_sponsor_employer_staff_role, aasm_state: 'is_active', benefit_sponsor_employer_profile_id: employer_profile.id) }
    let!(:person) { FactoryBot.create(:person, employer_staff_roles: [active_employer_staff_role]) }
    let!(:new_person_for_staff) { FactoryBot.create(:person) }
    let(:applicant_employer_staff_role) {FactoryBot.create(:benefit_sponsor_employer_staff_role, aasm_state: 'is_applicant', benefit_sponsor_employer_profile_id: employer_profile.id)}
    let!(:applicant_person) { FactoryBot.create(:person,employer_staff_roles: [applicant_employer_staff_role]) }
    let(:user) { FactoryBot.create(:user, :person => person)}

    describe "GET #new" do
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

      context "when accessing the new form" do
        before do
          sign_in user
          get :new, xhr: true
        end

        it "renders the new template" do
          expect(response).to render_template("new")
        end

        it "initializes the staff" do
          expect(assigns(:staff)).to be_a(staff_class)
        end

        it "returns a successful http status" do
          expect(response).to have_http_status(:success)
        end
      end

      context "when user has an employer staff role" do
        context "with POC role" do
          before do
            employer_staff_person.employer_staff_roles << er_staff_role
            employer_staff_person.save!
            sign_in employer_staff_user
          end

          it "allows the current user to access the new form" do
            get :new, xhr: true

            expect(response).to be_successful
          end
        end

        context "without POC role" do
          before do
            sign_in employer_staff_user
          end

          it "denies access to the new form for the current user" do
            get :new, xhr: true

            expect(flash[:error]).to eq("Access not allowed for esr_new?, (Pundit policy)")
          end
        end
      end

      context "when user has a broker role" do
        context "with an authorized account" do
          before do
            profile.broker_agency_accounts << BenefitSponsors::Accounts::BrokerAgencyAccount.new(benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, writing_agent_id: broker_role.id, start_on: Time.now,is_active: true)
            sign_in broker_role_user
          end

          it "allows the broker to access the new form" do
            get :new, xhr: true

            expect(response).to be_successful
          end
        end

        context "with an inactive broker role" do
          before do
            broker_role.update!(aasm_state: 'inactive')
            sign_in broker_role_user
          end

          it "denies access to the new form for the broker" do
            get :new, xhr: true

            expect(flash[:error]).to eq("Access not allowed for esr_new?, (Pundit policy)")
          end
        end
      end
    end

    describe "POST create", dbclean: :after_each do

      context "creating staff role with existing person params" do

        let!(:staff_params) {
          {
              :profile_id => employer_profile.id,
              :staff => {:first_name => new_person_for_staff.first_name, :last_name => new_person_for_staff.last_name, :dob => new_person_for_staff.dob}
          }
        }

        before :each do
            sign_in user
            post :create, params: staff_params
        end

        it "should initialize staff" do
          expect(assigns(:staff).class).to eq staff_class
        end

        it "should redirect" do
          expect(response).to have_http_status(:redirect)
        end

        it "should redirect to edit page of benefit_sponsor" do
          expect(response).to redirect_to(edit_profiles_registration_path(id:employer_profile.id))
          expect(response.location.include?("edit")).to eq true
        end

        it "should get an notice" do
          expect(flash[:notice]).to match /Role added sucessfully/
        end
      end

      context "creating staff role with non existing person params" do

        let!(:staff_params) {
          {
              :profile_id => employer_profile.id,
              :staff => {:first_name => "first_name", :last_name => 'last_name', :dob => "10/10/1989"}
          }
        }

        before :each do
          sign_in user
          post :create, params: staff_params
        end

        it "should redirect" do
          expect(response).to have_http_status(:redirect)
        end

        it "should redirect to edit page of benefit_sponsor" do
          expect(response).to redirect_to(edit_profiles_registration_path(id:employer_profile.id))
          expect(response.location.include?("edit")).to eq true
        end

        it "should get an error" do
          expect(flash[:error]).to match /Role was not added because Person does not exist on the HBX Exchange/
        end
      end
    end

    describe "GET approve", dbclean: :after_each do

      context "approve applicant staff role" do

        let!(:staff_params) {
          {
              :id => employer_profile.id, :person_id => applicant_person.id
          }
        }

        before :each do
          sign_in user
          get :approve, params: staff_params
        end

        it "should initialize staff" do
          expect(assigns(:staff).class).to eq staff_class
        end

        it "should redirect" do
          expect(response).to have_http_status(:redirect)
        end

        it "should redirect to edit page of benefit_sponsor" do
          expect(response).to redirect_to(edit_profiles_registration_path(id:employer_profile.id))
          expect(response.location.include?("edit")).to eq true
        end

        it "should get an notice" do
          expect(flash[:notice]).to match /Role is approved/
        end

        it "should update employer_staff_role aasm_state to is_active" do
          applicant_employer_staff_role.reload
          expect(applicant_employer_staff_role.aasm_state).to eq "is_active"
        end

      end

      context "approving invalid staff role" do

          let!(:staff_params) {
            {
                :id => employer_profile.id, :person_id => applicant_person.id
            }
          }

          before :each do
            sign_in user
            applicant_employer_staff_role.update_attributes(aasm_state:'is_closed')
            get :approve, params: staff_params
          end

        it "should redirect" do
          expect(response).to have_http_status(:redirect)
        end

        it "should redirect to edit page of benefit_sponsor" do
          expect(response).to redirect_to(edit_profiles_registration_path(id:employer_profile.id))
          expect(response.location.include?("edit")).to eq true
        end

        it "should get an error" do
          expect(flash[:error]).to match /Please contact HBX Admin to report this error/
        end
      end
    end


    describe "DELETE destroy", dbclean: :after_each do

      context "should deactivate staff role" do

        let!(:staff_params) {
          {
              :id => employer_profile.id, :person_id => applicant_person.id
          }
        }

        before :each do
          sign_in user
          delete :destroy, params: staff_params
        end

        it "should initialize staff" do
          expect(assigns(:staff).class).to eq staff_class
        end

        it "should redirect" do
          expect(response).to have_http_status(:redirect)
        end

        it "should redirect to edit page of benefit_sponsor" do
          expect(response).to redirect_to(edit_profiles_registration_path(id:employer_profile.id))
          expect(response.location.include?("edit")).to eq true
        end

        it "should get an notice" do
          expect(flash[:notice]).to match /Staff role was deleted/
        end

        it "should update employer_staff_role aasm_state to is_active" do
          applicant_employer_staff_role.reload
          expect(applicant_employer_staff_role.aasm_state).to eq "is_closed"
        end

      end

      context "should not deactivate only staff role of employer" do

        let!(:staff_params) {
          {
              :id => employer_profile.id, :person_id => person.id
          }
        }

        before :each do
          applicant_employer_staff_role.update_attributes(benefit_sponsor_employer_profile_id: new_benefit_sponsor.employer_profile.id)
          sign_in user
          delete :destroy, params: staff_params
        end

        it "should redirect" do
          expect(response).to have_http_status(:redirect)
        end

        it "should redirect to edit page of benefit_sponsor" do
          expect(response).to redirect_to(edit_profiles_registration_path(id:employer_profile.id))
          expect(response.location.include?("edit")).to eq true
        end

        it "should get an error" do
          expect(flash[:error]).to match /Role was not deactivated because Please add another staff role before deleting this role/
        end
      end
    end
  end
end
