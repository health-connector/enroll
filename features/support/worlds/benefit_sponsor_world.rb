module BenefitSponsorWorld
  def current_effective_date
    TimeKeeper.date_of_record
  end
  
  def shop_benefit_market
    @benefit_market ||= FactoryGirl.create(:benefit_markets_benefit_market, site: site, kind: :aca_shop)
  end
  
  def benefit_market_catalog
    @benefit_market_catalog ||= FactoryGirl.create(:benefit_markets_benefit_market_catalog, :with_product_packages,
      benefit_market: benefit_market,
      title: "SHOP Benefits for #{current_effective_date.year}",
      application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year)
    )
  end
  
  def product_package
    benefit_market_catalog.product_packages.first
  end

  
  def employer_profile
    employer.employer_profile
  end
  
  def employer_attestation
    @employer_attestation ||= BenefitSponsors::Documents::EmployerAttestation.new(aasm_state: "approved")
  end
  
  def benefit_sponsorship(employer=nil)
    @benefit_sponsorship ||= FactoryGirl.create(
      :benefit_sponsors_benefit_sponsorship,
      :with_rating_area,
      :with_service_areas,
      supplied_rating_area: rating_area,
      service_area_list: [service_area],
      organization: employer,
      profile_id: employer.profiles.first.id,
      benefit_market: shop_benefit_market,
      employer_attestation: employer_attestation)
  end
end

World(BenefitSponsorWorld)

Given(/^this benefit application has a benefit package containing (?:both ?)(.*?)(?: and ?)(.*?) benefits$/) do |health, dental|
  p dental
end
