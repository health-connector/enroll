require 'rails_helper'

describe "shared/_my_portal_links.html.haml" do

  context "with employer staff role" do
    let(:user) {FactoryGirl.create(:user, person: person, roles: ["employer_staff"])}
    let(:person) {FactoryGirl.create(:person, :with_employer_staff_role)}

    it "should have Add Employee Role link" do
      sign_in(user)
      render 'shared/my_portal_links'
      expect(rendered).to have_content("Add Employee Role")
      expect(rendered).to have_link("Add Employee Role", href: "/insured/employee/search")
    end
  end

  context "with Broker Agency Profile" do
    let(:user) {FactoryGirl.create(:user, person: person, roles: ["broker_agency_staff"])}
    let(:person) {FactoryGirl.create(:person, :with_broker_role)}

    it "should not have Add Employee role link" do
      sign_in(user)
      render 'shared/my_portal_links'
      expect(rendered).not_to have_content("Add Employee Role")
      expect(rendered).to have_content("My Broker Agency Portal")
    end
  end

  context "with Employee Role alone" do
    let(:user) {FactoryGirl.create(:user, person: person, roles: ["employee"])}
    let(:person) {FactoryGirl.create(:person, :with_employee_role)}

    it "should not have Add Employee role link" do
      sign_in(user)
      render 'shared/my_portal_links'
      expect(rendered).not_to have_content("Add Employee Role")
      expect(rendered).not_to have_content("My Broker Agency Portal")
      expect(rendered).to_not have_selector('dropdownMenu1')
    end
  end

  context "with Employee Role and Staff Role" do
    let!(:employee_role) { FactoryGirl.create(:employee_role, person: person)}
    let(:user) { FactoryGirl.create(:user, person: person, roles: %w(employer_staff employee)) }
    let(:profile) { person.employer_staff_roles.first.profile}
    let(:person) {FactoryGirl.create(:person, :with_employer_staff_role)}
    let(:census_employee) {FactoryGirl.create(:benefit_sponsors_census_employee, employee_role_id: employee_role.id)}

    context "Associated to a single employer profile" do
      it "should able to switch between 2 accounts" do
        employee_role.new_census_employee = census_employee
        allow(user).to receive(:has_employee_role?).and_return(true)
        sign_in(user)
        render 'shared/my_portal_links'
        expect(rendered).not_to have_content("Add Employee Role")
        expect(rendered).to have_content('My Insured Portal')
        expect(rendered).to have_content(profile.legal_name)
        expect(rendered).to have_selector('.dropdown-menu')
      end
    end

    context "Associated to two employer profiles" do
      let(:general_organization) { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_site, :with_aca_shop_cca_employer_profile) }
      let(:second_employer_profile) { general_organization.employer_profile}
      let!(:employer_staff_role) { FactoryGirl.create(:employer_staff_role, person: person, employer_profile_id: second_employer_profile.id, benefit_sponsor_employer_profile_id: second_employer_profile.id)}

      it "should able to switch between 2 accounts" do
        employee_role.new_census_employee = census_employee
        allow(user).to receive(:has_employee_role?).and_return(true)
        sign_in(user)
        render 'shared/my_portal_links'
        expect(rendered).not_to have_content("Add Employee Role")
        expect(rendered).to have_content('My Insured Portal')
        expect(rendered).to have_content(profile.legal_name)
        expect(rendered).to have_content(second_employer_profile.legal_name)
        expect(rendered).to have_selector('.dropdown-menu')
      end
    end
  end
end

