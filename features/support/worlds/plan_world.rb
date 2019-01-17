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
    benefit_market_catalog = BenefitMarkets::BenefitMarketCatalog.all.last
    FactoryGirl.create :benefit_sponsors_organizations_issuer_profile, assigned_site: @site
    product_package_kind = :single_issuer
    product_package = benefit_market_catalog.product_packages.where(package_kind: product_package_kind).first

    product = product_package.products.first
    service_area = FactoryGirl.create(:benefit_markets_locations_service_area)
    5.times do 
      product = FactoryGirl.create(:benefit_markets_products_health_products_health_product, :with_renewal_product, service_area: service_area)
      plan = FactoryGirl.create(:plan, hios_id: product.hios_id)
    end
  end
end

World(PlanWorld)

Given(/^the carrier plan (.*?) exists?/) do |carrier_plan|
  #load_old_model_product_and_carrier_plan
  # It appears that the proper single carrier products are created. For example:
  # products = BenefitMarkets::Products::Product.all.to_a
  # products.select { |product| product.product_package_kinds.include?(:single_issuer) }.count
  # this returns "16"
  # are they not displayng when clicking "one carrier" because of the service area? zip code?
  load_carriers
end

Given /a plan year(?:, )?(.*)(?:,) exists/ do |traits|
  plan *traits.sub(/, (and )?/, ',').gsub(' ', '_').split(',').map(&:to_sym), market: 'shop', coverage_kind: 'health', deductible: 4000
end
