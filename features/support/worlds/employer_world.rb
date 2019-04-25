module EmployerWorld
  def employer(legal_name, *traits)
    attributes = traits.extract_options!
    traits.push(:with_aca_shop_cca_employer_profile) unless traits.include? :with_aca_shop_cca_employer_profile_no_attestation
    @organization ||= {}
    @organization[legal_name] ||= FactoryGirl.create(
      :benefit_sponsors_organizations_general_organization, *traits,
      attributes.merge(site: site)
    )
  end

  def employer_profile(legal_name)
    @employer_profile = employer(legal_name).employer_profile
  end

  def registering_employer
    @registering_organization ||= FactoryGirl.build(
      :benefit_sponsors_organizations_general_organization,
      :with_aca_shop_cca_employer_profile,
      site: site
    )
  end

  def staff_role(legal_name=nil)
    @staff_role ||= FactoryGirl.create(
      :user,
      person: FactoryGirl.create(
        :person,
        employer_staff_roles: [
          FactoryGirl.build(
            :benefit_sponsor_employer_staff_role,
            aasm_state: 'is_active',
            benefit_sponsor_employer_profile_id: employer(legal_name).employer_profile.id
          )
        ]
      )
    )
  end
end

World(EmployerWorld)

And(/^there is an employer (.*?)$/) do |legal_name|
  employer legal_name, legal_name: legal_name, dba: legal_name
  benefit_sponsorship(employer(legal_name))
end

Given(/^at least one attestation document status is (.*?)$/) do |status|
  @employer_attestation_status = status
end

Given(/^employer (.*?) has hired this broker$/) do |legal_name|
  assign_broker_agency_account
  assign_person_to_broker_agency
  employer_profile(legal_name).hire_broker_agency(broker_agency_profile)
  # Need to fix below later
  employer_profile(legal_name).benefit_sponsorships.first.active_broker_agency_account.update(writing_agent_id:broker.person.broker_role.id)
end

And(/^(.*?) employer has a staff role$/) do |legal_name|
  staff_role(legal_name)
end

And(/^staff role person logged in$/) do
  login_as staff_role, scope: :user
end

And(/^(.*?) is logged in and on the home page$/) do |legal_name|
  employer_profile = employer(legal_name).employer_profile
  visit benefit_sponsors.profiles_employers_employer_profile_path(employer_profile.id, :tab => 'home')
end

And(/^(.*?) employer terminates employees$/) do |legal_name|
  termination_date = TimeKeeper.date_of_record - 1.day
  census_employees.each do |employee|
    employee.terminate_employment(termination_date)
  end
end
