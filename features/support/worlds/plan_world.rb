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
    year = TimeKeeper.date_of_record.year
    plan = FactoryGirl.create :plan, :with_premium_tables, active_year: year, market: 'shop', coverage_kind: 'health', deductible: 4000, is_sole_source: false
    plan2 = FactoryGirl.create :plan, :with_premium_tables, active_year: (year - 1), market: 'shop', coverage_kind: 'health', deductible: 4000, carrier_profile_id: plan.carrier_profile_id, is_sole_source: false
    sole_source_plan = FactoryGirl.create_list :plan, 4, :with_rating_factors, :with_premium_tables, active_year: year, market: 'shop', coverage_kind: 'health', deductible: 4000, carrier_profile_id: plan.carrier_profile_id, is_vertical: false, is_horizontal: false, is_sole_source: true
    sole_source_plan_two = FactoryGirl.create_list :plan, 4, :with_rating_factors, :with_premium_tables, active_year: (year - 1), market: 'shop', coverage_kind: 'health', deductible: 4000, carrier_profile_id: plan.carrier_profile_id, is_vertical: false, is_horizontal: false, is_sole_source: true

    # carrier_service_area = FactoryGirl.create(:carrier_service_area, issuer_hios_id: '11111', serves_entire_state: true, service_area_id: 'EX123', service_area_zipcode: "01001")






    # carrier_profile = FactoryGirl.create(:carrier_profile, legal_name: "Harvard Pilgrim Health Care", dba: "Harvard Pilgrim Health Care")
    # plan = FactoryGirl.create(:active_individual_health_plan, :with_premium_tables, carrier_profile: carrier_profile)
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
