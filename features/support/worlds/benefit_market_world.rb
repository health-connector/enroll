module BenefitMarketWorld
  def benefit_market
    @benefit_market ||= site.benefit_markets.first
  end

  def rating_area
    @rating_area ||= FactoryGirl.create(:benefit_markets_locations_rating_area)
  end

  def current_effective_date
    @current_effective_date = (TimeKeeper.date_of_record + 2.months).beginning_of_month.prev_year
  end

  def renewal_effective_date
    @renewal_effective_date = current_effective_date.next_year
  end

  def prior_rating_area
    @prior_rating_area ||= FactoryGirl.create(:benefit_markets_locations_rating_area, active_year: current_effective_date.year - 1)
  end

  def current_rating_area
    @current_rating_area ||= FactoryGirl.create(:benefit_markets_locations_rating_area, active_year: current_effective_date.year)
  end

  def renewal_rating_area
    @renewal_rating_area ||= FactoryGirl.create(:benefit_markets_locations_rating_area, active_year: renewal_effective_date.year)
  end

  def product_kinds
    @product_kinds = [:health]
  end

  def service_area
    county_zip_id = FactoryGirl.create(:benefit_markets_locations_county_zip, county_name: 'Middlesex', zip: '01754', state: 'MA').id
    @service_area ||= FactoryGirl.create(:benefit_markets_locations_service_area, county_zip_ids: [county_zip_id], active_year: current_effective_date.year)
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
      metal_level_kind: :gold
    )
  end

  def dental_products
    @dental_products ||= FactoryGirl.create_list(:benefit_markets_products_dental_products_dental_product,
      5,
      :with_renewal_product,
      application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
      product_package_kinds: [:single_product],
      service_area: service_area,
      renewal_service_area: renewal_service_area,
      metal_level_kind: :dental
    )
  end

  def current_benefit_market_catalog
    @current_benefit_market_catalog ||= FactoryGirl.create(:benefit_markets_benefit_market_catalog, :with_product_packages,
      benefit_market: benefit_market,
      product_kinds: product_kinds,
      title: "SHOP Benefits for #{current_effective_date.year}",
      application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year)
    )
  end

  def renewal_benefit_market_catalog
    @renewal_benefit_market_catalog ||= FactoryGirl.create(:benefit_markets_benefit_market_catalog, :with_product_packages,
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

end

World(BenefitMarketWorld)
