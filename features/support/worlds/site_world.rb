# frozen_string_literal: true

module SiteWorld
  def site
    @site ||= FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, Settings.site.key)
  end

  def site_with_exempt_organization
    FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :with_owner_exempt_organization_and_issuer_profile,  Settings.site.key)
  end

  def reset_product_cache
    BenefitMarkets::Products::ProductFactorCache.initialize_factor_cache!
    BenefitMarkets::Products::ProductRateCache.initialize_rate_cache!
  end
end

World(SiteWorld)

Given(/^a (.*?) site exists with a benefit market$/) do |_key|
  site
  make_all_permissions
  generate_sic_codes
end

Given(/^a (.*?) site exists with a benefit market and exempt organization$/) do |_key|
  site_with_exempt_organization
  make_all_permissions
  generate_sic_codes
end
