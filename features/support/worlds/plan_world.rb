module PlanWorld
  def plan(*traits)
    attributes = traits.extract_options!
    @plan ||= FactoryGirl.create :plan, *traits, attributes
  end

  def load_old_model_product_and_carrier_plan
    product = FactoryGirl.create(:benefit_markets_products_health_products_health_product)
    FactoryGirl.create(:plan, hios_id: product.hios_id)
    FactoryGirl.create(:carrier_profile)
  end

  def load_carriers
    #benefit_market_catalog = BenefitMarkets::BenefitMarketCatalog.all.last
    #FactoryGirl.create :benefit_sponsors_organizations_issuer_profile, assigned_site: @site
    #product_package_kind = :single_issuer
    #product_package = benefit_market_catalog.product_packages.where(package_kind: product_package_kind).first

    #product = product_package.products.first
    #service_area = FactoryGirl.create(:benefit_markets_locations_service_area)
    #service_area_zip = registering_employer.employer_profile.office_locations.first.address.zip
    #service_area.add_to_set(county_zip_ids: service_area_zip)
    #service_area.save
    #5.times do 
    #  product = FactoryGirl.create(:benefit_markets_products_health_products_health_product, :with_renewal_product, service_area: service_area)
    #  plan = FactoryGirl.create(:plan, hios_id: product.hios_id, service_area_id: service_area.id)
    #end
    carrier_profile = FactoryGirl.create(:carrier_profile, legal_name: "Harvard Pilgrim Health Care", dba: "Harvard Pilgrim Health Care")
    plan = FactoryGirl.create(:active_individual_health_plan, :with_premium_tables, carrier_profile: carrier_profile)
    #health_product = FactoryGirl.create(:benefit_markets_products_health_products_health_product)
    #health_product.add_to_set(county_zip_ids: service_area.zip)
  end
end

World(PlanWorld)

Given(/^that carriers with proposal plans exist/) do
  load_carriers
end


Given /a plan year(?:, )?(.*)(?:,) exists/ do |traits|
  plan *traits.sub(/, (and )?/, ',').gsub(' ', '_').split(',').map(&:to_sym), market: 'shop', coverage_kind: 'health', deductible: 4000
end
