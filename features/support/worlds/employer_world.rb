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

  def employer_quote(*traits)
    attributes = traits.extract_options!
    @employer_quote ||= FactoryGirl.create(
      :sponsored_benefits_plan_design_organization,
      *traits,
      attributes.merge(sponsor_profile_id: nil)
    ).tap do |quote|
      update_initial_enrollment_period(quote, Date.today.at_beginning_of_month.next_month.next_month..Date.today.at_end_of_month.next_month.next_month)
    
    end
  end

  private

  def update_initial_enrollment_period(quote,period)
    quote.plan_design_proposals.first.profile.benefit_sponsorships.first.update_attributes initial_enrollment_period: period
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

Given(/^(.*?) has a valid quote for (.*?)?$/) do |broker, employer|
  employer_quote :with_profile, owner_profile_id: broker_agency_profile.id
end

Given(/^ABC Widgets does not have a benefit application$/) do
  expect(@employer_profile.benefit_sponsorships.first.benefit_applications.present?).to be_falsy
end
