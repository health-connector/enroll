module BenefitSponsorWorld

  def benefit_sponsorship(employer = nil)
    @benefit_sponsorship ||= employer.employer_profile.add_benefit_sponsorship.tap do |benefit_sponsorship|
      benefit_sponsorship.save
    end
  end

  def benefit_sponsor_catalog
    @benefit_sponsor_catalog ||= FactoryGirl.create(:benefit_markets_benefit_sponsor_catalog, service_areas: [service_area])
  end

  def benefit_application
    @benefit_application ||= ::BenefitSponsors::BenefitApplications::BenefitApplicationFactory.call(
      benefit_sponsorship,
      effective_period: Range.new(Date.today.beginning_of_month, Date.today.beginning_of_month+1.year),
      open_enrollment_period: Range.new(Date.today, Date.today+::BenefitSponsors::BenefitApplications::AcaShopApplicationEligibilityPolicy::OPEN_ENROLLMENT_DAYS_MIN),
      fte_count: 5,
      pte_count: 0,
      msp_count: 0
    )
  end
end

World(BenefitSponsorWorld)

Given(/^this benefit application has a benefit package containing (?:both ?)(.*?)(?: and ?)(.*?) benefits$/) do |health, dental|
  benefit_application
end
