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

  def build_enrollment(house_hold, benefit_group_assignment, employee_role, benefit_package, *traits)
    @hbx_enrollment ||= FactoryGirl.create(
      :hbx_enrollment, 
      :with_enrollment_members,
      *traits,
      household: house_hold,
      benefit_group_assignment: benefit_group_assignment,
      sponsored_benefit_package_id: benefit_package.id,
      rating_area_id: benefit_package.benefit_application.recorded_rating_area_id,
      employee_role: employee_role,
      sponsored_benefit_id: benefit_package.sponsored_benefits.first.id,
    )
  end

  def create_person_and_user_from_census_employee(person)
    census_employee = CensusEmployee.where(first_name: person[:first_name], last_name: person[:last_name]).first
    employer = @organization.values.first
    employer_profile = @organization.values.first.profiles.first
    employer_staff_role = FactoryGirl.build(:benefit_sponsor_employer_staff_role, aasm_state:'is_active', benefit_sponsor_employer_profile_id: employer_profile.id)
    @person_record ||= FactoryGirl.create(
      :person,
      first_name: person[:first_name],
      last_name: person[:last_name],
      ssn: person[:ssn],
      dob: person[:dob_date],
      census_employee_id: census_employee.id,
      employer_profile_id: employer_profile.id,
      employer_staff_roles:[employer_staff_role],
      hired_on: census_employee.hired_on
    )
    census_employee.update_attributes(employee_role_id: employer_staff_role.id)
    #@person_family_record ||= FactoryGirl.create(:family, :with_primary_family_member, person: @person_record)
    @person_user_record = FactoryGirl.create(:user, :person => @person_record)
  end

    def employee(employer=nil)
    if @employee
      @employee
    else
      employer_staff_role = FactoryGirl.build(:benefit_sponsor_employer_staff_role, aasm_state:'is_active', benefit_sponsor_employer_profile_id: employer.profiles.first.id)
      person = FactoryGirl.create(:person, employer_staff_roles:[employer_staff_role])
      @employee = FactoryGirl.create(:user, :person => person)
    end
  end

  def create_census_employee_from_person(person)
    organization = @organization.values.first || nil
    current_sponsorship = benefit_sponsorship(organization)
    current_benefit_group = @current_application.benefit_packages.first
    @census_employee ||= FactoryGirl.create(
      :census_employee,
      :with_active_assignment,
      first_name: person[:first_name],
      last_name: person[:last_name],
      dob: person[:dob_date],
      ssn: person[:ssn],
      benefit_sponsorship: current_sponsorship,
      employer_profile: organization.employer_profile,
      benefit_group: current_benefit_group
    )
  end

  def census_employee_from_person(person)
    CensusEmployee.where(first_name: person[:first_name], last_name: person[:last_name]).first
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

  build_enrollment(coverage_household, bga, census_employee.employee_role, benefit_package)
end

And(/^employer (.*?) with employee (.*?) is under open enrollment$/) do |legal_name, named_person|
  person = people[named_person]
  create_person_and_user_from_census_employee(person)
  person = @person_record
  census_employee = CensusEmployee.first
  bga =  census_employee.active_benefit_group_assignment
  benefit_package = fetch_benefit_group(legal_name)
  coverage_household = @person_family_record.households.first

  build_enrollment(coverage_household, bga, census_employee.employee_role, benefit_package)
end

And(/^employer (.*?) with employee (.*?) has hbx_enrollment with health product$/) do |legal_name, named_person|
  person = people[named_person]
  create_person_and_user_from_census_employee(person)
  person = @person_record
  census_employee = CensusEmployee.where(first_name: person[:first_name], last_name: person[:last_name]).first
  bga =  census_employee.active_benefit_group_assignment
  benefit_package = fetch_benefit_group(legal_name)
  coverage_household = @person_record.families.first.households.first
  build_enrollment(coverage_household, bga, census_employee.employee_role, benefit_package, :with_health_product)
end

And(/^employer (.*?) with employee (.*?) has terminated hbx_enrollment with health product$/) do |legal_name, named_person|
  person = people[named_person]
  create_person_and_user_from_census_employee(person)
  person = @person_record
  census_employee = CensusEmployee.where(first_name: person[:first_name], last_name: person[:last_name]).first
  bga =  census_employee.active_benefit_group_assignment
  benefit_package = fetch_benefit_group(legal_name)
  coverage_household = @person_record.families.first.households.first
  build_enrollment(coverage_household, bga, census_employee.employee_role, benefit_package, :terminated, :with_health_product)
end