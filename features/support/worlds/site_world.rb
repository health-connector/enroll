module SiteWorld
  def create_site
    @site ||= FactoryGirl.create(:benefit_sponsors_site,:with_benefit_market, :with_benefit_market_catalog_and_product_packages, :as_hbx_profile, Settings.site.key)
    @rating_area ||= FactoryGirl.create(:benefit_markets_locations_rating_area)
    @service_area ||= FactoryGirl.create(:benefit_markets_locations_service_area)
  end
end

World(SiteWorld)
