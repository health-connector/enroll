module CensusEmployeeWorld
  def census_employees(roster_count = 1, *traits)
    attributes = traits.extract_options!
    @census_employees ||= FactoryGirl.create_list(:census_employee, roster_count, attributes)
  end

  def fetch_benefit_group(legal_name)
    org_by_legal_name(legal_name).benefit_sponsorships.first.benefit_applications.first.benefit_packages.first
  end

  def org_by_legal_name(legal_name)
    @org_by_legal_name ||= @organization[legal_name]
  end

  def build_enrollment(house_hold, benefit_group_assignment, employee_role, benefit_package)
    @hbx_enrollment ||= FactoryGirl.create(:hbx_enrollment, :with_enrollment_members,
                                           household: house_hold,
                                           benefit_group_assignment: benefit_group_assignment,
                                           sponsored_benefit_package_id: benefit_package.id,
                                           rating_area_id: benefit_package.benefit_application.recorded_rating_area_id,
                                           employee_role: employee_role,
                                           sponsored_benefit_id: benefit_package.sponsored_benefits.first.id)
  end

end

World(CensusEmployeeWorld)

And(/^there (are|is) (\d+) (employee|employees) for (.*?)$/) do |_, roster_count, _, legal_name|
  sponsorship = org_by_legal_name(legal_name).benefit_sponsorships.first
  census_employees roster_count.to_i, benefit_sponsorship: sponsorship, employer_profile: sponsorship.profile
end

And(/^Employees for (.*?) have both Benefit Group Assignments Employee role$/) do |legal_name|
  #make it more generic by name

  step "Assign benefit group assignments to #{legal_name} employee"

  employer_profile = org_by_legal_name(legal_name).employer_profile

  @census_employees.each do |employee|
    person = FactoryGirl.create(:person, :with_family, first_name: employee.first_name, last_name: employee.last_name, dob: employee.dob, ssn: employee.ssn)
    employee_role = FactoryGirl.create(:employee_role, person: person, benefit_sponsors_employer_profile_id: employer_profile.id)
    employee.update_attributes(employee_role_id: employee_role.id)
  end
end

And(/^Assign benefit group assignments to (.*?) employee$/) do |legal_name|
  # try to fetch it from benefit application world
  benefit_package = fetch_benefit_group(legal_name)
  @census_employees.each do |employee|
    employee.add_benefit_group_assignment(benefit_package)
  end
end

And(/^employees for (.*?) have a selected coverage$/) do |legal_name|

  step "Employees for #{legal_name} have both Benefit Group Assignments Employee role"

  person = @census_employees.first.employee_role.person
  bga =  @census_employees.first.active_benefit_group_assignment
  benefit_package = fetch_benefit_group(legal_name)

  coverage_household = person.primary_family.households.first

  build_enrollment(coverage_household, bga, @census_employees.first.employee_role, benefit_package)
  @census_user = FactoryGirl.create(:user, person: person)
end
