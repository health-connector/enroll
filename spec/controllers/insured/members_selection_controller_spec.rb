require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe Insured::MembersSelectionController, type: :controller, dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"
  include_context "setup employees with benefits"

  let!(:ce) { benefit_sponsorship.census_employees.first }
  let!(:ee_person) { FactoryGirl.create(:person, :with_employee_role, :with_family, first_name: ce.first_name, last_name: ce.last_name, dob: ce.dob, ssn: ce.ssn, gender: ce.gender) }
  let!(:user) { FactoryGirl.create(:user, :person => ee_person)}
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
        get :new, person_id: ee_person.id, employee_role_id: employee_role.id
        expect(response).to have_http_status(:success)
      end
    end


    context "with two member family" do
      let!(:dependent) { FactoryGirl.create(:person) }
      let!(:family_member) { FactoryGirl.create(:family_member, family: family,person: dependent)}
      let!(:coverage_household_member) { coverage_household.coverage_household_members.new(:family_member_id => family_member.id) }

      it "return http success" do
        get :new, person_id: ee_person.id, employee_role_id: employee_role.id
        expect(response).to have_http_status(:success)
      end
    end
  end
end