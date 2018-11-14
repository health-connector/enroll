require 'rails_helper'

describe "shared/_my_portal_links.html.haml" do

  context "with employer staff role" do
    let(:user) { FactoryGirl.create(:user, person: person, roles: ["employer_staff"])}
    let(:person) { FactoryGirl.create(:person, :with_employer_staff_role) }

    it "should have Add Employee Role link" do
      sign_in(user)
      render 'shared/my_portal_links'
      expect(rendered).to have_content("Add Employee Role")
      expect(rendered).to have_link("Add Employee Role", href: "/insured/employee/search")
    end
  end

  context "with Broker Agency Profile" do
    let(:user) { FactoryGirl.create(:user, person: person, roles: ["broker_agency_staff"])}
    let(:person) { FactoryGirl.create(:person, :with_broker_role) }

    it "should not have Add Employee role link" do
      sign_in(user)
      render 'shared/my_portal_links'
      expect(rendered).not_to have_content("Add Employee Role")
      expect(rendered).to have_content("My Broker Agency Portal")
    end
  end

  context "with Employee Role alone" do
    let(:user) { FactoryGirl.create(:user, person: person, roles: ["employee"]) }
    let(:person) { FactoryGirl.create(:person, :with_employee_role)}

    it "should not have Add Employee role link" do
      sign_in(user)
      render 'shared/my_portal_links'
      expect(rendered).not_to have_content("Add Employee Role")
      expect(rendered).not_to have_content("My Broker Agency Portal")
      expect(rendered).to_not have_selector('dropdownMenu1')
    end
  end

  context "with Employee Role and Staff Role person" do
    let(:user) { FactoryGirl.create(:user, person: person, roles: ["employer_staff", "employee"]) }
    let(:person) { FactoryGirl.create(:person, :with_employer_staff_role, :with_employee_role)}
    let(:benefit_sponsorship) { FactoryGirl.create(:benefit_sponsors_benefit_sponsorship, :with_benefit_market, :with_organization_cca_profile, :with_initial_benefit_application)}
    let(:census_employee) { FactoryGirl.create(:benefit_sponsors_census_employee, employee_role: person.employee_roles.first)}

    it "should able to switch between 2 accounts" do
      sign_in(user)
      allow(person.employee_roles.first).to receive(:census_employee).and_return(census_employee)
      render 'shared/my_portal_links'
      expect(rendered).not_to have_content("Add Employee Role")
      expect(rendered).to have_content('My Insured Portal')
      expect(rendered).to have_content(all_er_profile.legal_name)
      expect(rendered).to have_selector('.dropdown-menu')
    end

  end



  # context "with employer role & employee role" do
  #   let(:user) { FactoryGirl.create(:user, person: person, roles: ["employee", "employer_staff"]) }
  #   let(:site)            { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  #   let(:benefit_sponsor)     { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
  #   let(:employer_profile)    { benefit_sponsor.employer_profile }
  #   let(:active_employer_staff_role) {FactoryGirl.create(:benefit_sponsor_employer_staff_role, aasm_state:'is_active', benefit_sponsor_employer_profile_id: employer_profile.id)}
  #   let(:person) { FactoryGirl.create(:person, :with_employee_role, employer_staff_roles:[active_employer_staff_role]) }
  #   let(:benefit_sponsorship)    { BenefitSponsors::BenefitSponsorships::BenefitSponsorship.new(profile: employer_profile, benefit_market: site.benefit_markets.first) }
  #
  #   it "should have one portal links and popover" do
  #     allow(employer_profile).to receive(:active_benefit_sponsorship).and_return(benefit_sponsorship)
  #     all_census_ee = FactoryGirl.create(:census_employee, employer_profile: employer_profile)
  #     all_er_profile = all_census_ee.employer_profile
  #     person.employee_roles.first.census_employee = all_census_ee
  #     person.employee_roles.first.save!
  #     sign_in(user)
  #     render 'shared/my_portal_links'
  #     expect(rendered).to have_content('My Insured Portal')
  #     expect(rendered).to have_content(all_er_profile.legal_name)
  #     expect(rendered).to have_selector('.dropdown-menu')
  #     expect(rendered).to have_selector('.dropdown-menu')
  #     expect(rendered).to match(/Insured/)
  #   end
  # end

  # context "with employer roles & employee role" do
  #   let(:user) { FactoryGirl.create(:user, person: person, roles: ["employee", "employer_staff"]) }
  #   # let(:person) { FactoryGirl.create(:person, :with_employee_role, :with_employer_staff_role)}
  #   let(:site)            { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  #   let(:benefit_sponsor)     { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
  #   let(:employer_profile)    { benefit_sponsor.employer_profile }
  #   let(:active_employer_staff_role) {FactoryGirl.create(:benefit_sponsor_employer_staff_role, aasm_state:'is_active', benefit_sponsor_employer_profile_id: employer_profile.id)}
  #   let(:person) { FactoryGirl.create(:person, :with_employee_role, employer_staff_roles:[active_employer_staff_role]) }
  #   let(:benefit_sponsorship)    { BenefitSponsors::BenefitSponsorships::BenefitSponsorship.new(profile: employer_profile, benefit_market: site.benefit_markets.first) }
  #
  #   it "should have one portal links and popover" do
  #     allow(employer_profile).to receive(:active_benefit_sponsorship).and_return(benefit_sponsorship)
  #     all_census_ee = FactoryGirl.create(:census_employee, employer_profile: employer_profile)
  #     all_er_profile = all_census_ee.employer_profile
  #     all_er_profile.organization.update_attributes(legal_name: 'Second Company') # not always Turner
  #     EmployerStaffRole.create(person:person, benefit_sponsor_employer_profile_id: all_er_profile.id)
  #     person.employee_roles.first.census_employee = all_census_ee
  #     person.employee_roles.first.save!
  #     sign_in(user)
  #     render 'shared/my_portal_links'
  #     expect(rendered).to have_content('My Insured Portal')
  #     expect(rendered).to have_content(all_er_profile.legal_name)
  #     expect(rendered).to have_content('Second Company')
  #     expect(rendered).to have_selector('.dropdown-menu')
  #     expect(rendered).to have_selector('.dropdown-menu')
  #     expect(rendered).to match(/Insured/)
  #   end
  # end

end
