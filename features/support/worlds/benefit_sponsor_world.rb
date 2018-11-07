module BenefitSponsorWorld

  def benefit_sponsorship(employer)
    @benefit_sponsorship ||= BenefitSponsors::BenefitSponsorships::BenefitSponsorship.new(profile: employer.employer_profile)
  end

  def benefit_sponsor_catalog
    @benefit_sponsor_catalog ||= FactoryGirl.create(:benefit_markets_benefit_sponsor_catalog, service_areas: [service_area])
  end

  def benefit_application
    @benefit_application ||= FactoryGirl.create(:benefit_sponsors_benefit_application,
        :with_benefit_package,
        :fte_count => 10,
        :open_enrollment_period => Range.new(Date.today, Date.today + BenefitApplications::AcaShopApplicationEligibilityPolicy::OPEN_ENROLLMENT_DAYS_MIN),
      )
  end
end

World(BenefitSponsorWorld)

Given(/^this benefit application has a benefit package containing (?:both ?)(.*?)(?: and ?)(.*?) benefits$/) do |health, dental|
  p dental
end
