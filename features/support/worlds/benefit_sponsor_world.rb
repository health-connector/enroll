module BenefitSponsorWorld
  def build_benefit_sponsorship(legal_name)
    @organization ||= FactoryGirl.create(:benefit_sponsors_organizations_general_organization, @state, site: @site)
    @organization.legal_name = legal_name
    @organization.dba = legal_name
    @employer_profile ||= @organization.employer_profile
    @benefit_sponsorship ||= @organization.employer_profile.benefit_sponsorships
  end
end

World(BenefitSponsorWorld)

And(/^this benefit application has a benefit package containing both (.*?) and (.*?) benefits$/) do |health, dental|
  p dental
end
