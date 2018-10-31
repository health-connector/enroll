module SiteWorld
  def site
    @site ||= FactoryGirl.create(:benefit_sponsors_site, :as_hbx_profile, Settings.site.key)
  end
  
  def rating_area
    @rating_area ||= FactoryGirl.create(:benefit_markets_locations_rating_area)
  end
  
  def service_area
    @service_area ||= FactoryGirl.create(:benefit_markets_locations_service_area)
  end
end

World(SiteWorld)

Given(/^a CCA site exists with a health benefit market$/) do

end