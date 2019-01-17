module EmployerWorld

  def employer(*traits)
    attributes = traits.extract_options!
    @organization ||= FactoryGirl.create(
      :benefit_sponsors_organizations_general_organization,
      :with_aca_shop_cca_employer_profile,
      attributes.merge(site: site)
    )
  end

  def registering_employer
     @registering_organization ||= FactoryGirl.build(
       :benefit_sponsors_organizations_general_organization,
       :with_aca_shop_cca_employer_profile,
       site: site)
   end

  def employer_profile
    @employer_profile = employer.employer_profile
  end
end

World(EmployerWorld)

And(/^there is an employer (.*?)$/) do |legal_name|
  employer legal_name: legal_name,
           dba: legal_name
  benefit_sponsorship(employer)

end

Given(/^at least one attestation document status is (.*?)$/) do |status|
  @employer_attestation_status = status
end

Given(/^employer (.*?) has hired this broker$/) do |employer|
  assign_broker_agency_account
  assign_person_to_broker_agency
  employer_profile.hire_broker_agency(broker_agency_profile)
  # Need to fix below later
  employer_profile.benefit_sponsorships.first.active_broker_agency_account.update(writing_agent_id:broker.person.broker_role.id)
end

And(/^the broker has a prospect employer$/) do
  url = "/sponsored_benefits/organizations/plan_design_organizations/new?broker_agency_id=#{broker_agency_profile.id}"
  visit url
  fill_in_prospective_employer_form
end

And(/^a quote for the brokers prospect employer exists$/) do
  find('.dropdown.pull-right', text: 'Actions').click
  click_link 'Create Quote'
  fill_in_quotes_form
  wait_for_ajax
  expect(page).to have_content("Quote information saved successfully.")
end

And(/^prospect employer has an employee on the roster$/) do
  wait_for_ajax
  Capybara.ignore_hidden_elements = false
  links = page.all('a')
  add_employee_link = links.detect { |link| link.text == "Add Employee" }
  add_employee_link.trigger('click')
  Capybara.ignore_hidden_elements = true
  fill_in_add_employee_form
end