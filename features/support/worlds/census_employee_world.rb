module CensusEmployeeWorld
  def census_employees(roster_count = 1, *traits)
    attributes = traits.extract_options!
    @census_employees ||= FactoryGirl.create_list(:census_employee, roster_count, attributes)
  end

  def fetch_benefit_group(legal_name)
    employer_profile(legal_name).organization.benefit_sponsorships.first.benefit_applications.first.benefit_packages.first
  end

  def build_enrollment(attributes, *traits)
    @hbx_enrollment ||= FactoryGirl.create(
      :hbx_enrollment,
      :with_enrollment_members,
      *traits,
      household: attributes[:household],
      benefit_group_assignment: attributes[:benefit_group_assignment],
      employee_role: attributes[:employee_role],
      rating_area_id: attributes[:rating_area_id],
      sponsored_benefit_id: attributes[:sponsored_benefit_id],
      sponsored_benefit_package_id: attributes[:sponsored_benefit_package_id]
    )
  end

  def person_record_from_census_employee(person, legal_name = nil, organizations = nil)
    organizations.reject! { |organization| @organization.values.include?(organization) == false }
    census_employee = CensusEmployee.where(first_name: person[:first_name], last_name: person[:last_name]).first
    employer_prof = employer_profile(legal_name)
    employer = employer_prof.organization
    emp_staff_role = FactoryGirl.create(
      :benefit_sponsor_employer_staff_role,
      aasm_state: 'is_active',
      benefit_sponsor_employer_profile_id: employer_prof.id
    )
    if Person.where(first_name: person[:first_name], last_name: person[:last_name]).present?
      person_record = Person.where(first_name: person[:first_name], last_name: person[:last_name]).first
      person_record.employer_staff_roles << emp_staff_role
      person_record.save
    else
      person_record = FactoryGirl.build(
        :person_with_employee_role,
        :with_family,
        first_name: person[:first_name],
        last_name: person[:last_name],
        ssn: person[:ssn],
        dob: person[:dob_date],
        census_employee_id: census_employee.id,
        employer_profile_id: employer_prof.id,
        employer_staff_roles:[emp_staff_role],
        hired_on: census_employee.hired_on
      )
    end
    if organizations.present?
      emp_staff_roles = []
      organizations.each do |organization|
        employer_prof = employer.profiles.first
        emp_staff_role = FactoryGirl.create(
          :benefit_sponsor_employer_staff_role,
          aasm_state: 'is_active',
          benefit_sponsor_employer_profile_id: employer_prof.id
        )
        emp_staff_roles << emp_staff_role
      end
      person_record.employer_staff_roles = emp_staff_roles
      person_record.save!
    else
      person_record.save!
    end
    person_record
  end

  def user_record_from_census_employee(person)
    person_record = Person.where(first_name: person[:first_name], last_name: person[:last_name]).first
    @person_user_record ||= FactoryGirl.create(:user, :person => person_record)
  end

  def employee(employer=nil)
    if @employee
      @employee
    else
      employer_staff_role = FactoryGirl.build(:benefit_sponsor_employer_staff_role, aasm_state: 'is_active', benefit_sponsor_employer_profile_id: employer.profiles.first.id)
      person = FactoryGirl.create(:person, employer_staff_roles:[employer_staff_role])
      @employee = FactoryGirl.create(:user, :person => person)
    end
  end

  def create_census_employee_from_person(person, legal_name = nil)
    employer_profile = employer_profile(legal_name)
    organization = employer_profile.organization
    sponsorship = benefit_sponsorship(organization)
    benefit_group = fetch_benefit_group(organization.legal_name)
    FactoryGirl.create(
      :census_employee,
      :with_active_assignment,
      first_name: person[:first_name],
      last_name: person[:last_name],
      dob: person[:dob_date],
      ssn: person[:ssn],
      benefit_sponsorship: sponsorship,
      employer_profile: employer_profile,
      benefit_group: benefit_group
    )
  end

  def census_employee_from_person(person)
    CensusEmployee.where(first_name: person[:first_name], last_name: person[:last_name]).first
  end
end

World(CensusEmployeeWorld)

And(/^there (are|is) (\d+) (employee|employees) for (.*?)$/) do |_, roster_count, _, legal_name|
  sponsorship = employer(legal_name).benefit_sponsorships.first
  census_employees roster_count.to_i, benefit_sponsorship: sponsorship, employer_profile: sponsorship.profile
end

And(/^Employees for (.*?) have both Benefit Group Assignments Employee role$/) do |legal_name|
  step "Assign benefit group assignments to #{legal_name} employee"
  employer_profile = employer_profile(legal_name)
  census_employees = employer_profile.census_employees
  census_employees.each do |employee|
    person = FactoryGirl.create(:person, :with_family, first_name: employee.first_name, last_name: employee.last_name, dob: employee.dob, ssn: employee.ssn)
    employee_role = FactoryGirl.create(:employee_role, person: person, benefit_sponsors_employer_profile_id: employer_profile.id)
    employee.update_attributes(employee_role_id: employee_role.id)
  end
end

And(/^Assign benefit group assignments to (.*?) employee$/) do |legal_name|
  benefit_package = fetch_benefit_group(legal_name)
  employer_profile = employer_profile(legal_name)
  census_employees = employer_profile.census_employees

  census_employees.each do |employee|
    employee.add_benefit_group_assignment(benefit_package)
  end
end

And(/^employees for (.*?) have a selected coverage$/) do |legal_name|
  employer_profile = employer_profile(legal_name)
  census_employees = employer_profile.census_employees

  step "Employees for #{legal_name} have both Benefit Group Assignments Employee role"

  person = census_employees.first.employee_role.person
  bga =  census_employees.first.active_benefit_group_assignment
  benefit_package = fetch_benefit_group(legal_name)
  coverage_household = person.primary_family.households.first
  rating_area_id =  benefit_package.benefit_application.recorded_rating_area_id
  sponsored_benefit_id = benefit_package.sponsored_benefits.first.id

  build_enrollment({household: coverage_household,
                    benefit_group_assignment: bga,
                    employee_role: census_employees.first.employee_role,
                    sponsored_benefit_package_id: benefit_package.id,
                    rating_area_id: rating_area_id,
                    sponsored_benefit_id: sponsored_benefit_id})
end
