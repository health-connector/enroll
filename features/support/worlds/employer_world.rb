module EmployerWorld

  def employer(*traits)
    attributes = traits.extract_options!
    @organization ||= FactoryGirl.create(
      :benefit_sponsors_organizations_general_organization,
      :with_aca_shop_cca_employer_profile,
      attributes.merge(site: site)
    )
  end

  def employer_profile
    @employer_profile = employer.employer_profile
  end

  def prospect_employer
    @prospect_employer ||= FactoryGirl.build(
      :benefit_sponsors_organizations_general_organization,
      :with_aca_shop_cca_employer_profile,
      site: site)
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
  fill_in_prospect_employer_form
  find('.interaction-click-control-confirm', text: 'Confirm').click
end

And(/^there is a quote for ABC Prospect named (.*?)$/) do |quote_name|
  find('.dropdown.pull-right', text: 'Actions').click
  click_link 'Create Quote'
  fill_in_quotes_form quote_name
  wait_for_ajax
  expect(page).to have_content("Quote information saved successfully.")
  find('a.interaction-click-control-employers', text: 'Employers').trigger('click')
end