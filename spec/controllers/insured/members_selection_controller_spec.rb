# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe Insured::MembersSelectionController, type: :controller, dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"
  include_context "setup employees with benefits"

  let!(:ce) { benefit_sponsorship.census_employees.first }
  let!(:ee_person) { FactoryBot.create(:person, :with_employee_role, :with_family, first_name: ce.first_name, last_name: ce.last_name, dob: ce.dob, ssn: ce.ssn, gender: ce.gender) }
  let!(:user) { FactoryBot.create(:user, :person => ee_person)}
  let!(:employee_role) do
    ee_person.employee_roles.first.update_attributes!(employer_profile: abc_profile)
    ee_person.employee_roles.first
  end
  let!(:family)       { ee_person.primary_family }
  let!(:primary_family_member)       { family.primary_family_member }
  let!(:coverage_household)       { family.active_household.immediate_family_coverage_household }

  before :each do
    ce.employee_role_id = employee_role.id
    ce.save
    employee_role.census_employee_id = ce.id
    ee_person.save
    sign_in user
  end

  context "GET new" do
    context "with one member family and no dental offering" do
      it "return http success" do
        get :new, params: {person_id: ee_person.id, employee_role_id: employee_role.id}
        expect(response).to have_http_status(:success)
      end
    end

    context "with two member family" do
      let!(:dependent) { FactoryBot.create(:person) }
      let!(:family_member) { FactoryBot.create(:family_member, family: family,person: dependent)}
      let!(:coverage_household_member) { coverage_household.coverage_household_members.new(:family_member_id => family_member.id) }

      it "return http success" do
        get :new, params: {person_id: ee_person.id, employee_role_id: employee_role.id}
        expect(response).to have_http_status(:success)
      end
    end

    context "when the logged-in user is not authorized to access the create, new, eligible_coverage_selection and fetch actions" do
      let(:fake_person) { FactoryBot.create(:person, :with_employee_role) }
      let(:fake_user) { FactoryBot.create(:user, person: fake_person) }
      let!(:fake_family) { FactoryBot.create(:family, :with_primary_family_member, person: fake_person) }

      it "redirects to the root path and displays an error message" do
        sign_in(fake_user)

        post :create, params: {person_id: ee_person.id, employee_role_id: employee_role.id, family_id: family.id}

        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("Access not allowed for family_policy.member_selection_coverage?, (Pundit policy)")
      end

      shared_examples_for "logged in user has no authorization roles for MembersSelectionController" do |action|
        it "redirects to the root path and displays an error message" do
          sign_in(fake_user)

          get action, params: {person_id: ee_person.id, employee_role_id: employee_role.id, family_id: family.id}

          expect(response).to redirect_to(root_path)
          expect(flash[:error]).to eq("Access not allowed for family_policy.member_selection_coverage?, (Pundit policy)")
        end
      end

      it_behaves_like 'logged in user has no authorization roles for MembersSelectionController', :new
      it_behaves_like 'logged in user has no authorization roles for MembersSelectionController', :eligible_coverage_selection
      it_behaves_like 'logged in user has no authorization roles for MembersSelectionController', :fetch
    end
  end

  context "with two employee roles" do
    let(:census_employee_2){FactoryBot.build(:census_employee)}
    let!(:employee_role_2){FactoryBot.build(:employee_role, person: ee_person, :census_employee => census_employee_2)}

    it "return http success" do
      get :new, params: {person_id: ee_person.id, employee_role_id: employee_role_2.id}
      expect(response).to have_http_status(:success)
    end
  end
end
