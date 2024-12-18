# frozen_string_literal: true

require File.join(File.dirname(__FILE__), "..", "support/benefit_sponsors_site_spec_helpers")

RSpec.shared_context "setup benefit market with market catalogs and product packages", :shared_context => :metadata do

  let(:site)                    { ::BenefitSponsors::SiteSpecHelpers.create_cca_site_with_hbx_profile_and_benefit_market }
  let(:benefit_market)          { site.benefit_markets.first }
  let(:rating_area)             { create_default(:benefit_markets_locations_rating_area) }
  # let(:benefit_market)          { create(:benefit_markets_benefit_market, site_urn: 'mhc', kind: :aca_shop, title: "MA Health Connector SHOP Market") }

  let(:current_effective_date)  { (TimeKeeper.date_of_record + 2.months).beginning_of_month.prev_year }
  let(:renewal_effective_date)  { current_effective_date.next_year }
  let(:catalog_health_package_kinds) { [:single_issuer, :metal_level, :single_product] }
  let(:catalog_dental_package_kinds) { [:single_product] }


  let!(:prior_rating_area)   { create(:benefit_markets_locations_rating_area, active_year: current_effective_date.year - 1) }
  let!(:current_rating_area) { create(:benefit_markets_locations_rating_area, active_year: current_effective_date.year) }
  let!(:renewal_rating_area) { create(:benefit_markets_locations_rating_area, active_year: renewal_effective_date.year) }

  let(:product_kinds)  { [:health] }

  let(:service_area) do
    county_zip_id = create(:benefit_markets_locations_county_zip, county_name: 'Middlesex', zip: '01754', state: 'MA').id
    create(:benefit_markets_locations_service_area, county_zip_ids: [county_zip_id], active_year: current_effective_date.year)
  end
  let(:renewal_service_area) do
    create(:benefit_markets_locations_service_area, county_zip_ids: service_area.county_zip_ids, active_year: service_area.active_year + 1)
  end
  let!(:issuer_profile)  { FactoryBot.create :benefit_sponsors_organizations_issuer_profile, assigned_site: site}
  let!(:health_products) do
    create_list(
      :benefit_markets_products_health_products_health_product,
      5,
      :with_renewal_product,
      issuer_profile: issuer_profile,
      application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
      product_package_kinds: [:single_issuer, :metal_level, :single_product],
      service_area: service_area,
      renewal_service_area: renewal_service_area,
      metal_level_kind: :gold
    )
  end

  let!(:dental_products) do
    create_list(
      :benefit_markets_products_dental_products_dental_product,
      5,
      :with_renewal_product,
      issuer_profile: issuer_profile,
      application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
      product_package_kinds: [:single_product],
      service_area: service_area,
      renewal_service_area: renewal_service_area,
      metal_level_kind: :dental
    )
  end
  let!(:current_benefit_market_catalog) do
    create(
      :benefit_markets_benefit_market_catalog,
      :with_product_packages,
      benefit_market: benefit_market,
      product_kinds: product_kinds,
      title: "SHOP Benefits for #{current_effective_date.year}",
      application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year)
    )
  end
  let!(:renewal_benefit_market_catalog) do
    create(
      :benefit_markets_benefit_market_catalog,
      :with_product_packages,
      benefit_market: benefit_market,
      product_kinds: product_kinds,
      title: "SHOP Benefits for #{renewal_effective_date.year}",
      application_period: (renewal_effective_date.beginning_of_year..renewal_effective_date.end_of_year)
    )
  end
  #
  # before do
  #   map_products
  # end
  #
  # def map_products
  #   current_benefit_market_catalog.product_packages.each do |product_package|
  #     if renewal_product_package = renewal_benefit_market_catalog.product_packages.detect{ |p|
  #       p.package_kind == product_package.package_kind && p.product_kind == product_package.product_kind }
  #
  #       renewal_product_package.products.each_with_index do |renewal_product, i|
  #         current_product = product_package.products[i]
  #         current_product.update(renewal_product_id: renewal_product.id)
  #       rescue StandardError => ex
  #         binding.irb
  #       end
  #     end
  #   end
  # end
end
