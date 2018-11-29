require 'factory_girl'

BenefitSponsors::Site.destroy_all
BenefitMarkets::BenefitMarket.destroy_all
BenefitMarkets::BenefitMarketCatalog.destroy_all

puts '::: Creating Site with Benefit Market :::'
start = Time.now
site = FactoryGirl.create(:benefit_sponsors_site, :as_hbx_profile, Settings.site.key)
benefit_market = FactoryGirl.create(:benefit_markets_benefit_market, site: site, kind: :aca_shop)
BenefitMarkets::Products::ProductFactorCache.initialize_factor_cache!
BenefitMarkets::Products::ProductRateCache.initialize_rate_cache!
issuer_profile = FactoryGirl.create(:benefit_sponsors_organizations_issuer_profile, assigned_site: site)
puts '::: Creating Rating Area :::'
rating_area = FactoryGirl.create(:benefit_markets_locations_rating_area)
current_effective_date = (TimeKeeper.date_of_record + 2.months).beginning_of_month.prev_year
renewal_effective_date = current_effective_date.next_year
prior_rating_area = FactoryGirl.create(:benefit_markets_locations_rating_area, active_year: current_effective_date.year - 1)
current_rating_area = FactoryGirl.create(:benefit_markets_locations_rating_area, active_year: current_effective_date.year)
renewal_rating_area = FactoryGirl.create(:benefit_markets_locations_rating_area, active_year: renewal_effective_date.year)
product_kinds = [:health]
puts '::: Creating Service Area :::'
county_zip_id = FactoryGirl.create(:benefit_markets_locations_county_zip, county_name: 'Middlesex', zip: '01754', state: 'MA').id
service_area = FactoryGirl.create(:benefit_markets_locations_service_area, county_zip_ids: [county_zip_id], active_year: current_effective_date.year)
renewal_service_area = FactoryGirl.create(:benefit_markets_locations_service_area, county_zip_ids: service_area.county_zip_ids, active_year: service_area.active_year + 1)
puts '::: Creating Products :::'
health_products = FactoryGirl.create_list(
          :benefit_markets_products_health_products_health_product,
          5,
          :with_renewal_product,
          application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
          product_package_kinds: [:single_issuer, :metal_level, :single_product],
          service_area: service_area,
          renewal_service_area: renewal_service_area,
          metal_level_kind: :gold,
          issuer_profile_id: issuer_profile.id,
          premium_ages: 20..20
)
dental_products = FactoryGirl.create_list(:benefit_markets_products_dental_products_dental_product,
          5,
          :with_renewal_product,
          application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
          product_package_kinds: [:single_product],
          service_area: service_area,
          renewal_service_area: renewal_service_area,
          metal_level_kind: :dental,
          issuer_profile_id: issuer_profile.id,
          premium_ages: 20..20
)
puts '::: Creating Market Catalogs :::'
current_benefit_market_catalog = FactoryGirl.create(:benefit_markets_benefit_market_catalog, :with_product_packages,
    benefit_market: benefit_market,
    product_kinds: product_kinds,
    title: "SHOP Benefits for #{current_effective_date.year}",
    application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year)
)
renewal_benefit_market_catalog = FactoryGirl.create(:benefit_markets_benefit_market_catalog, :with_product_packages,
    benefit_market: benefit_market,
    product_kinds: product_kinds,
    title: "SHOP Benefits for #{renewal_effective_date.year}",
    application_period: (renewal_effective_date.beginning_of_year..renewal_effective_date.end_of_year)
)

current_benefit_market_catalog.product_packages.each do |product_package|
  if renewal_product_package = renewal_benefit_market_catalog.product_packages.detect{ |p|
    p.package_kind == product_package.package_kind && p.product_kind == product_package.product_kind }

    renewal_product_package.products.each_with_index do |renewal_product, i|
      current_product = product_package.products[i]
      current_product.update(renewal_product_id: renewal_product.id)
    end
  end
end

puts '::: Completed setting up Benefit Market :::'

puts '::: Creating Benefit Sponsors and Benefit Applications :::'
path = File.open(Rails.root.join 'db', 'builds', 'companies.json')
file = File.read(path)
data_hash = JSON.parse(file)

first_names = File.open(Rails.root.join 'db', 'builds', 'first_names.json')
ff = File.read(first_names)
first_names_hash = JSON.parse(ff)['firstNames']

last_names = File.open(Rails.root.join 'db', 'builds', 'sur_names.json')
ln = File.read(last_names)
last_names_hash = JSON.parse(ln)['lastNames']

#Clears bad organizations created from rake:db:seed
BenefitSponsors::Organizations::GeneralOrganization.where(legal_name:/acme widgets/i).each do |org|
  org.destroy
end

data_hash['companies'].each_with_index do |company,i|
  organization = FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site, legal_name: company, dba:company)
  employer_profile = organization.employer_profile
  benefit_sponsorship = employer_profile.add_benefit_sponsorship
  benefit_sponsorship.save
  person = FactoryGirl.create(:person, :with_mailing_address, :with_ssn, first_name: first_names_hash.sample, last_name: last_names_hash.sample)
  employer_staff_role = EmployerStaffRole.create(person: person, benefit_sponsor_employer_profile_id: employer_profile.id)
  aasm_state = :active
  package_kind = :single_issuer
  effective_period = current_effective_date..current_effective_date.next_year.prev_day
  open_enrollment_start_on = effective_period.min.prev_month
  open_enrollment_period = open_enrollment_start_on..(effective_period.min - 10.days)
  dental_sponsored_benefit = false
  gender = %w[male female]

  service_areas = benefit_sponsorship.service_areas_on(effective_period.min)
  benefit_sponsor_catalog = benefit_sponsorship.benefit_sponsor_catalog_for(service_areas, effective_period.min)

  if i < 200
    initial_application = BenefitSponsors::BenefitApplications::BenefitApplication.new(
        # benefit_sponsorship: benefit_sponsorship,
        benefit_sponsor_catalog: benefit_sponsor_catalog,
        effective_period: effective_period,
        aasm_state: aasm_state,
        open_enrollment_period: open_enrollment_period,
        recorded_rating_area: rating_area,
        recorded_service_areas: service_areas,
        fte_count: rand(1..10),
        pte_count: rand(1..10),
        msp_count: 0
    )

    product_package = initial_application.benefit_sponsor_catalog.product_packages.detect { |package| package.package_kind == package_kind }
    dental_product_package = initial_application.benefit_sponsor_catalog.product_packages.detect { |package| package.product_kind == :dental }
    current_benefit_package = FactoryGirl.create(:benefit_sponsors_benefit_packages_benefit_package, health_sponsored_benefit: true, dental_sponsored_benefit: dental_sponsored_benefit, product_package: product_package, dental_product_package: dental_product_package, benefit_application: initial_application)
    initial_application.benefit_packages = [current_benefit_package]
    benefit_sponsorship.benefit_applications = [initial_application]

    enrollment_kinds = ['health']
    1.upto(initial_application.fte_count+initial_application.pte_count) do |e|
      ce = CensusEmployee.create(first_name: first_names_hash.sample, last_name: last_names_hash.sample, gender:gender.sample, ssn:rand.to_s[2..10], dob: '10/01/1990', benefit_sponsors_employer_profile_id: benefit_sponsorship.profile.id, benefit_sponsorship_id: benefit_sponsorship.id, hired_on: Date.today-rand(1..10).days)
    end
  end

  if i > 200
    initial_application = BenefitSponsors::BenefitApplications::BenefitApplication.new(
        # benefit_sponsorship: benefit_sponsorship,
        benefit_sponsor_catalog: benefit_sponsor_catalog,
        effective_period: effective_period,
        aasm_state: :terminated,
        open_enrollment_period: open_enrollment_period,
        recorded_rating_area: rating_area,
        recorded_service_areas: service_areas,
        fte_count: rand(1..10),
        pte_count: rand(1..10),
        msp_count: 0
    )

    product_package = initial_application.benefit_sponsor_catalog.product_packages.detect { |package| package.package_kind == package_kind }
    dental_product_package = initial_application.benefit_sponsor_catalog.product_packages.detect { |package| package.product_kind == :dental }
    current_benefit_package = FactoryGirl.create(:benefit_sponsors_benefit_packages_benefit_package, health_sponsored_benefit: true, dental_sponsored_benefit: dental_sponsored_benefit, product_package: product_package, dental_product_package: dental_product_package, benefit_application: initial_application)
    initial_application.benefit_packages = [current_benefit_package]
    benefit_sponsorship.benefit_applications = [initial_application]

    enrollment_kinds = ['health']
    1.upto(initial_application.fte_count+initial_application.pte_count) do |e|
      CensusEmployee.create(first_name: first_names_hash.sample, last_name: last_names_hash.sample, gender:gender.sample, ssn:rand.to_s[2..10], dob: '10/01/1990', benefit_sponsors_employer_profile_id: benefit_sponsorship.profile.id, benefit_sponsorship_id: benefit_sponsorship.id, hired_on: Date.today-rand(1..10).days)
    end
end




  if benefit_sponsorship.save! && benefit_sponsor_catalog.save!
    puts "::: Successfully created Benefit Application for #{company} :::"
  end
end

puts "::: Creating Brokers :::"
1.upto(10) do |n|
  names = %w[One Two Three Four Five Six Seven Eight Nine Ten]
  broker_organization = FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_broker_agency_profile, site: site, legal_name: "Broker #{names[n]}", dba: "Broker #{names[n]} Co." )
  broker_agency_profile = broker_organization.broker_agency_profile
  broker_agency_account = FactoryGirl.build(:benefit_sponsors_accounts_broker_agency_account, broker_agency_profile: broker_agency_profile)
  person = FactoryGirl.create(:person, :with_work_email, first_name: first_names_hash.sample, last_name: last_names_hash.sample)
  broker_role = FactoryGirl.build(:broker_role, aasm_state: 'active', benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, person: person)
  broker = FactoryGirl.create(:user, :person => person)
  broker_agency_profile.update_attributes!(primary_broker_role_id: broker.person.broker_role.id)
  broker_agency_profile.approve!
end

puts "::: Assigning Brokers to Employers :::"
BenefitSponsors::Organizations::Organization.employer_profiles.each do |organization|
  employer_profile = organization.employer_profile
  if employer_profile.active_benefit_sponsorship.present?
    broker = BenefitSponsors::Organizations::Organization.broker_agency_profiles.sample.broker_agency_profile
    bm = BenefitSponsors::Organizations::OrganizationForms::BrokerManagementForm.for_create(broker_agency_id: broker.id, broker_role_id: broker.primary_broker_role.id, employer_profile_id: employer_profile.id)
    if bm.save
      puts "::: Added broker to #{organization.legal_name} :::"
    end
  end
end

finish = Time.now
diff = finish - start
puts "::: Completed build in #{Time.at(diff).utc.strftime("%H:%M:%S")} :::"
