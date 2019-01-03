module EmployerWorld

  def employer(legal_name, *traits)
    attributes = traits.extract_options!
    @organization ||= {}
    @organization[legal_name] ||= FactoryGirl.create(
      :benefit_sponsors_organizations_general_organization,
      :with_aca_shop_cca_employer_profile,
      attributes.merge(site: site)
    )
  end

  def employer_profile(legal_name)
    @employer_profile = employer(legal_name).employer_profile
  end
end

World(EmployerWorld)

And(/^there is an employer (.*?)$/) do |legal_name|
  employer legal_name, legal_name: legal_name, dba: legal_name
  benefit_sponsorship(employer(legal_name))
end

And(/^there are (.*?) Employers present$/) do |how_many_employers|
  legal_names = []
  how_many_employers.to_i.times { |index| legal_names << "Fake Company No #{index}" }
  legal_names.each do |legal_name|
    employer legal_name, legal_name: legal_name, dba: legal_name
    benefit_sponsorship(employer(legal_name))
  end
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