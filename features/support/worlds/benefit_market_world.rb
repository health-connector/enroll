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
    @rating_area ||= FactoryBot.create(:benefit_markets_locations_rating_area, active_year: current_effective_date.year)
  end

  def renewal_rating_area(effective_date = renewal_effective_date)
    @renewal_rating_area ||= FactoryBot.create(:benefit_markets_locations_rating_area, active_year: effective_date.year)
  end

  def service_area
    @service_area ||= FactoryBot.create(:benefit_markets_locations_service_area, county_zip_ids: [county_zip.id], active_year: current_effective_date.year)
  end

  def renewal_service_area
    @renewal_service_area ||= FactoryBot.create(:benefit_markets_locations_service_area, county_zip_ids: service_area.county_zip_ids, active_year: renewal_effective_date.year)
  end

  def product_kinds(product_kinds = nil)
    if product_kinds.present?
      @product_kinds = product_kinds
    else
      @product_kinds ||= [:health, :dental]
    end
  end

  def county_zip
    @county_zip ||= FactoryBot.create(:benefit_markets_locations_county_zip,
      county_name: 'Middlesex',
      zip: '01754',
      state: 'MA'
    )
  end

  def issuer_profile(carrier=:default)
    @issuer_profile[carrier] ||= FactoryBot.create(:benefit_sponsors_organizations_issuer_profile, carrier, assigned_site: site)
  end

  def dental_issuer_profile(carrier=:default)
    @dental_issuer_profile[carrier] ||= FactoryBot.create(:benefit_sponsors_organizations_issuer_profile, carrier, assigned_site: site)
  end

  def qualifying_life_events
    @qualifying_life_events ||= [
      :effective_on_event_date,
      :effective_on_first_of_month
    ].map { |event_trait| FactoryBot.create(:qualifying_life_event_kind, event_trait, market_kind: "shop", post_event_sep_in_days: 90) }
  end

  def set_initial_application_dates(status)
    case status
    when :draft, :enrollment_open
      current_effective_date (TimeKeeper.date_of_record + 2.months).beginning_of_month
    when :enrollment_closed, :enrollment_eligible, :enrollment_extended
      current_effective_date (TimeKeeper.date_of_record + 1.months).beginning_of_month
    when :active, :terminated, :termination_pending, :expired, :retroactive_canceled
      current_effective_date (TimeKeeper.date_of_record - 2.months).beginning_of_month
    end
  end

  # Addresses certain cucumbers failing in Nov/Dec
  def safe_initial_application_dates(status)
    case status
    when :draft, :enrollment_open
      if TimeKeeper.date_of_record.month == 11 && TimeKeeper.date_of_record.day < 16
        current_effective_date TimeKeeper.date_of_record.beginning_of_month
      else
        current_effective_date (TimeKeeper.date_of_record + 2.months).beginning_of_month
      end
    when :enrollment_closed, :enrollment_eligible, :enrollment_extended
      current_effective_date (TimeKeeper.date_of_record + 1.months).beginning_of_month
    when :active, :terminated, :termination_pending, :expired, :retroactive_canceled
      current_effective_date (TimeKeeper.date_of_record - 2.months).beginning_of_month
    end
  end

  def set_renewal_application_dates(status)
    case status
    when :draft, :enrollment_open
      current_effective_date (TimeKeeper.date_of_record + 2.months).beginning_of_month.prev_year
    when :enrollment_closed, :enrollment_eligible, :enrollment_extended
      current_effective_date (TimeKeeper.date_of_record + 1.months).beginning_of_month.prev_year
    when :active, :terminated, :termination_pending, :expired, :retroactive_canceled
      current_effective_date (TimeKeeper.date_of_record - 1.months).beginning_of_month.prev_year
    end
  end

  # Addresses certain cucumbers failing in Nov/Dec
  def safe_renewal_application_dates(status)
    case status
    when :draft, :enrollment_open
      current_effective_date (TimeKeeper.date_of_record + 2.months).beginning_of_month.prev_year
    when :enrollment_closed, :enrollment_eligible, :enrollment_extended
      current_effective_date (TimeKeeper.date_of_record + 1.months).beginning_of_month.prev_year
    when :active, :terminated, :termination_pending, :expired, :retroactive_canceled
      if TimeKeeper.date_of_record.month > 10
        current_effective_date (TimeKeeper.date_of_record - 3.months).beginning_of_month.prev_year
      elsif TimeKeeper.date_of_record.month == 1
        current_effective_date TimeKeeper.date_of_record.beginning_of_month.prev_year
      else
        current_effective_date (TimeKeeper.date_of_record - 1.months).beginning_of_month.prev_year
      end
    end
  end

  def health_products(effective_date = current_effective_date)
    create_list(:benefit_markets_products_health_products_health_product,
                5,
                application_period: (effective_date.beginning_of_year..effective_date.end_of_year),
                product_package_kinds: [:single_issuer, :metal_level, :single_product],
                service_area: service_area,
                issuer_profile_id: issuer_profile.id,
                metal_level_kind: :gold)
  end

  def dental_products
    create_list(:benefit_markets_products_dental_products_dental_product,
        5,
        application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
        product_package_kinds: [:single_product],
        service_area: service_area,
        issuer_profile_id: dental_issuer_profile.id,
        metal_level_kind: :dental)
  end

  def generate_initial_catalog_products_for(coverage_kinds)
    product_kinds(coverage_kinds)
    health_products
    dental_products if coverage_kinds.include?(:dental)
    BenefitMarkets::Products::HealthProducts::HealthProduct.each do |hp|
      qhp = create(:products_qhp, active_year: hp.active_year, standard_component_id: hp.hios_id)
      csr = FactoryBot.build(:products_qhp_cost_share_variance, hios_plan_and_variant_id: hp.hios_id)
      qhp.qhp_cost_share_variances << csr
      qhp_d = FactoryBot.build(:products_qhp_deductible, in_network_tier_1_individual: "$100", in_network_tier_1_family: "$100 | $200")
      csr.qhp_deductibles << qhp_d
      qhp.save!
      csr.save!
      qhp_d.save!
      doc = FactoryBot.build(:document, identifier: '1:1#1')
      hp.sbc_document = doc
      hp.save!
      doc.save!
    end
    reset_product_cache
  end

  def renewal_health_products(effective_date = current_effective_date)
    create_list(:benefit_markets_products_health_products_health_product,
                5,
                :with_renewal_product,
                application_period: (effective_date.beginning_of_year..effective_date.end_of_year),
                product_package_kinds: [:single_issuer, :metal_level, :single_product],
                service_area: service_area,
                renewal_service_area: renewal_service_area,
                issuer_profile_id: issuer_profile.id,
                #renewal_issuer_profile_id: issuer_profile.id,
                metal_level_kind: :gold)
  end

  def renewal_dental_products
     create_list(:benefit_markets_products_dental_products_dental_product,
        5,
        :with_renewal_product,
        application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
        product_package_kinds: [:single_product],
        service_area: service_area,
        renewal_service_area: renewal_service_area,
        issuer_profile_id: dental_issuer_profile.id,
        #renewal_issuer_profile_id: dental_issuer_profile.id,
        metal_level_kind: :dental)
  end

  def generate_renewal_catalog_products_for(coverage_kinds)
    product_kinds(coverage_kinds)
    renewal_health_products
    renewal_dental_products if coverage_kinds.include?(:dental)
    reset_product_cache
  end

  def create_benefit_market_catalog_for(effective_date)
    @benefit_market_catalog =
      benefit_market.benefit_market_catalog_for(effective_date).presence || FactoryBot.create(
        :benefit_markets_benefit_market_catalog,
        :with_product_packages,
        benefit_market: benefit_market,
        product_kinds: product_kinds,
        title: "SHOP Benefits for #{effective_date.year}",
        application_period: (effective_date.beginning_of_year..effective_date.end_of_year)
      )
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
  if current_effective_date.month > 10
    generate_renewal_catalog_products_for(coverage_kinds)
    create_benefit_market_catalog_for(current_effective_date.next_year) unless BenefitMarkets::BenefitMarketCatalog.by_application_date(current_effective_date.next_year).present?
  end
end

# Addresses certain cucumbers failing in Nov/Dec
Given(/^SAFE benefit market catalog exists for (.*) initial employer with health benefits$/) do |status|
  safe_initial_application_dates(status.to_sym)
  generate_initial_catalog_products_for([:health])
  create_benefit_market_catalog_for(current_effective_date)
end

# Following step can be used to initialize benefit market catalog for renewing employer with health/dental benefits
# It will also create products needed for requested coverage kinds
# ex: benefit market catalog exists for enrollment_open renewal employer with health benefits
Given(/^benefit market catalog exists for (.*) renewal employer with (.*) benefits$/) do |status, coverage_kinds|
  coverage_kinds = [:health]
  set_renewal_application_dates(status.to_sym)
  generate_renewal_catalog_products_for(coverage_kinds)
  create_benefit_market_catalog_for(current_effective_date)
  create_benefit_market_catalog_for(renewal_effective_date)

  create_benefit_market_catalog_for(TimeKeeper.date_of_record.beginning_of_year.prev_year) if TimeKeeper.date_of_record.month > 10 && !BenefitMarkets::BenefitMarketCatalog.by_application_date(TimeKeeper.date_of_record.prev_year).present?
end

# Addresses certain cucumbers failing in Nov/Dec
Given(/^SAFE benefit market catalog exists for (.*) renewal employer with health benefits$/) do |status|
  safe_renewal_application_dates(status.to_sym)
  generate_renewal_catalog_products_for([:health])
  create_benefit_market_catalog_for(current_effective_date)
  create_benefit_market_catalog_for(renewal_effective_date)
end

Given(/^benefit market catalog exists for (.*) initial employer that has both health and dental benefits$/) do |status|
  coverage_kinds = [:health, :dental]
  set_initial_application_dates(status.to_sym)
  generate_initial_catalog_products_for(coverage_kinds)
  create_benefit_market_catalog_for(current_effective_date)
end

# Addresses certain cucumbers failing in Nov/Dec
Given(/^SAFE benefit market catalog exists for (.*) initial employer that has both health and dental benefits$/) do |status|
  coverage_kinds = [:health, :dental]
  safe_initial_application_dates(status.to_sym)
  generate_initial_catalog_products_for(coverage_kinds)
  create_benefit_market_catalog_for(current_effective_date)
end
