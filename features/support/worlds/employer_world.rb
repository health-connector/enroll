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
end

World(EmployerWorld)

And(/^there is an employer (.*?)$/) do |legal_name|
  employer legal_name: legal_name,
           dba: legal_name
  benefit_sponsorship(employer)
end

And(/^at least one attestation document status is (.*?)$/) do |status|
  @employer_attestation_status = status
end
