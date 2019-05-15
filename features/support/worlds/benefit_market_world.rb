module BenefitMarketWorld
  def benefit_market
    @benefit_market ||= site.benefit_markets.first
  end

  def current_effective_date(new_date = nil)
    if new_date.present?
      @current_effective_date = new_date
    else
      @current_effective_date ||= (TimeKeeper.date_of_record + 2.months).beginning_of_month
    end
  end

  def renewal_effective_date(new_date = nil)
    if new_date.present?
      @renewal_effective_date = new_date
    else
      @renewal_effective_date ||= current_effective_date.next_year
    end
  end

  def rating_area
    @rating_area ||= FactoryGirl.create(:benefit_markets_locations_rating_area, active_year: current_effective_date.year)
  end

  def renewal_rating_area
    @renewal_rating_area ||= FactoryGirl.create(:benefit_markets_locations_rating_area, active_year: renewal_effective_date.year)
  end

  def service_area
    @service_area ||= FactoryGirl.create(:benefit_markets_locations_service_area, county_zip_ids: [county_zip.id], active_year: current_effective_date.year)
  end

  def renewal_service_area
    @renewal_service_area ||= FactoryGirl.create(:benefit_markets_locations_service_area, county_zip_ids: service_area.county_zip_ids, active_year: renewal_effective_date.year)
  end

  def product_kinds(product_kinds = nil)
    if product_kinds.present?
      @product_kinds = product_kinds
    else
      @product_kinds ||= [:health, :dental]
    end
  end

  def service_area
    @service_area ||= FactoryGirl.create(:benefit_markets_locations_service_area, county_zip_ids: [county_zip.id], active_year: current_effective_date.year)
  end

  def county_zip
    @county_zip ||= FactoryGirl.create(:benefit_markets_locations_county_zip,
      county_name: 'Middlesex',
      zip: '01754',
      state: 'MA'
    )
  end

  def issuer_profile(carrier=:default)
    @issuer_profile[carrier] ||= FactoryGirl.create(:benefit_sponsors_organizations_issuer_profile, carrier, assigned_site: site)
  end

  def renewal_service_area
    @renewal_service_area ||= FactoryGirl.create(:benefit_markets_locations_service_area, county_zip_ids: service_area.county_zip_ids, active_year: service_area.active_year + 1)
  end

  def health_products
    @health_products ||= FactoryGirl.create_list(:benefit_markets_products_health_products_health_product,
      5,
      :with_renewal_product,
      application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
      product_package_kinds: [:single_issuer, :metal_level, :single_product],
      service_area: service_area,
      renewal_service_area: renewal_service_area,
      metal_level_kind: :gold,
      issuer_profile_id: issuer_profile.id,
      premium_ages: 20..20 #Get Trey to remove hack
    )
  end

  def dental_products
    @dental_products ||= FactoryGirl.create_list(:benefit_markets_products_dental_products_dental_product,
      5,
      :with_renewal_product,
      application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
      product_package_kinds: [:single_product,:single_issuer],
      service_area: service_area,
      renewal_service_area: renewal_service_area,
      metal_level_kind: :dental,
      issuer_profile_id: issuer_profile.id,
      premium_ages: 20..20 #Get Trey to remove hack
    )
  end

  def qualifying_life_events
    @qualifying_life_events ||= [
      :effective_on_event_date,
      :effective_on_first_of_month
    ].map { |event_trait| FactoryGirl.create(:qualifying_life_event_kind, event_trait) }
  end

  def build_product_package(product_kind, package_kind)
    build(:benefit_markets_products_product_package,
      packagable: nil,
      package_kind: package_kind,
      product_kind: product_kind,
      county_zip_id: county_zip.id,
      service_area: service_area,
      title: "#{package_kind.to_s.humanize} #{product_kind}",
      description: "#{package_kind.to_s.humanize} #{product_kind}",
      application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
    )
  end

  def current_benefit_market_catalog
    @current_benefit_market_catalog ||= FactoryGirl.create(:benefit_markets_benefit_market_catalog,
      :with_product_packages,
      benefit_market: benefit_market,
      product_kinds: product_kinds,
      title: "SHOP Benefits for #{current_effective_date.year}",
      application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year)
    )
  end

  def renewal_benefit_market_catalog
    @renewal_benefit_market_catalog ||= FactoryGirl.create(:benefit_markets_benefit_market_catalog,
      :with_product_packages,
      benefit_market: benefit_market,
      product_kinds: product_kinds,
      title: "SHOP Benefits for #{renewal_effective_date.year}",
      application_period: (renewal_effective_date.beginning_of_year..renewal_effective_date.end_of_year)
    )
  end

  def map_products
    current_benefit_market_catalog.product_packages.each do |product_package|
      if renewal_product_package = renewal_benefit_market_catalog.product_packages.detect{ |p|
        p.package_kind == product_package.package_kind && p.product_kind == product_package.product_kind }

        renewal_product_package.products.each_with_index do |renewal_product, i|
          current_product = product_package.products[i]
          current_product.update(renewal_product_id: renewal_product.id)
        end
      end
    end
  end

  def generate_initial_catalog_products_for(coverage_kinds)
    product_kinds(coverage_kinds)
    health_products
    dental_products if coverage_kinds.include?(:dental)
    reset_product_cache
  end

  def set_initial_application_dates(status)
    case status
    when :draft, :enrollment_open
      current_effective_date (TimeKeeper.date_of_record + 2.months).beginning_of_month
    when :enrollment_closed, :enrollment_eligible, :enrollment_extended
      current_effective_date (TimeKeeper.date_of_record + 1.months).beginning_of_month
    when :active, :terminated, :termination_pending, :expired
      current_effective_date (TimeKeeper.date_of_record - 2.months).beginning_of_month
    end
  end

  def create_benefit_market_catalog_for(effective_date)
    if benefit_market.benefit_market_catalog_for(effective_date).present?
      benefit_market.benefit_market_catalog_for(effective_date)
    else
      FactoryGirl.create(:benefit_markets_benefit_market_catalog, :with_product_packages,
        benefit_market: benefit_market,
        product_kinds: product_kinds,
        title: "SHOP Benefits for #{effective_date.year}",
        application_period: (effective_date.beginning_of_year..effective_date.end_of_year)
      )
    end
  end
end

World(BenefitMarketWorld)

Given(/^Qualifying life events are present$/) do
  qualifying_life_events
end

# Following step can be used to initialize benefit market catalog for initial employer with health/dental benefits
# It will also create products needed for requested coverage kinds
# ex: benefit market catalog exists for enrollment_open initial employer with health benefits
Given(/^benefit market catalog exists for (.*) initial employer with (.*) benefits$/) do |status, coverage_kinds|
  coverage_kinds = [:health]
  set_initial_application_dates(status.to_sym)
  generate_initial_catalog_products_for(coverage_kinds)
  create_benefit_market_catalog_for(current_effective_date)
end
