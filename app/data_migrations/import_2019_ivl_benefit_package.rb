# require File.join(Rails.root, "lib/mongoid_migration_task")

class Import2019IvlBenefitPackage < MongoidMigrationTask

  def update_or_create_ivl_benefit_application(benefit_sponsorship)
    # Second lowest cost silver plan
    #IVL_TODO Pull the correct product package
    slcsp_2019 = ::BenefitMarkets::Products::Product.all.first
    #Plan.where(active_year: year).and(hios_id: "94506DC0390006-01").first

    ivl_ba_2019 = benefit_sponsorship.ivl_benefit_applications.select { |iba| iba.effective_period.min.year == 2019 }.first

    if ivl_ba_2019.blank?
      # Create IvlBenefitApplication for year
      ivl_ba_2018 = hbx.benefit_sponsorship.benefit_coverage_periods.select { |bcp| bcp.start_on.year == 2018 }.first
      ivl_ba_2019 = benefit_sponsorship.ivl_benefit_applications.new
      ivl_ba_2019.effective_period = ((bc_period_2018.effective_period.min.next_year)..(bc_period_2018.effective_period.max.next_year))
      ivl_ba_2019.open_enrollment_period = ((Settings.aca.individual_market.open_enrollment.start_on)..(Settings.aca.individual_market.open_enrollment.end_on))
    end
    ivl_ba_2019.slcsp = slcsp_2019.id
    ivl_ba_2019.slcsp_id = slcsp_2019.id
    ivl_ba_2019.save!
    ivl_ba_2019
  end

  def migrate
    year_range_2019 = ((Date.new(2019).beginning_of_year)..(Date.new(2019).end_of_year))
    if Settings.site.key.to_s == "dc"
      say_with_time("Creating DC IvlBenefitApplication") do
        site = ::BenefitSponsors::Site.by_site_key("dc").first
        organization = site.owner_organization
        benefit_sponsorship = organization.active_benefit_sponsorship
        ivl_ba_2019 = update_or_create_ivl_benefit_application(benefit_sponsorship)
      end

      say_with_time("Creating DC IVLBenefitPackages") do
        ivl_2019_plans = ::BenefitMarkets::Products::Product.by_application_period(year_range_2019).aca_individual_market
        ivl_health_plan_ids_2019 = ivl_2019_plans.health_products.non_catastropic_plans.collect(&:_id) #ivl_health_plans_2019
        ivl_dental_plan_ids_2019 = ivl_2019_plans.dental_products.collect(&:_id) #ivl_dental_plans_2019
        ivl_and_cat_health_plan_ids_2019 = ivl_2019_plans.collect(&:_id) #ivl_and_cat_health_plans_2019

        ivl_health_plan_ids_2019_for_csr_100 = ::BenefitMarkets::Products::Product.health_individual_by_effective_period_and_csr_kind(year_range_2019).collect(&:_id) #ivl_health_plans_2019_for_csr_100
        ivl_health_plan_ids_2019_for_csr_94 = ::BenefitMarkets::Products::Product.health_individual_by_effective_period_and_csr_kind(year_range_2019, "csr_94").collect(&:_id) #ivl_health_plans_2019_for_csr_94
        ivl_health_plan_ids_2019_for_csr_87 = ::BenefitMarkets::Products::Product.health_individual_by_effective_period_and_csr_kind(year_range_2019, "csr_87").collect(&:_id) #ivl_health_plans_2019_for_csr_87
        ivl_health_plan_ids_2019_for_csr_73 = ::BenefitMarkets::Products::Product.health_individual_by_effective_period_and_csr_kind(year_range_2019, "csr_73").collect(&:_id) #ivl_health_plans_2019_for_csr_73

        ## 2019 Benefit Packages
        individual_health_benefit_package = ::IvlBenefitSponsors::IvlBenefitPackages::IvlBenefitPackage.new(
          title: "individual_health_benefits_2019",
          elected_premium_credit_strategy: "unassisted",
          benefit_ids:          ivl_health_plan_ids_2019,
          benefit_eligibility_element_group: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup.new(
              market_places:        ["individual"],
              enrollment_periods:   ["open_enrollment", "special_enrollment"],
              family_relationships: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup::INDIVIDUAL_MARKET_RELATIONSHIP_CATEGORY_KINDS,
              benefit_categories:   ["health"],
              incarceration_status: ["unincarcerated"],
              age_range:            0..0,
              citizenship_status:   ["us_citizen", "naturalized_citizen", "alien_lawfully_present", "lawful_permanent_resident"],
              residency_status:     ["state_resident"],
              ethnicity:            ["any"]
            )
        )

        individual_dental_benefit_package = ::IvlBenefitSponsors::IvlBenefitPackages::IvlBenefitPackage.new(
          title: "individual_dental_benefits_2019",
          elected_premium_credit_strategy: "unassisted",
          benefit_ids:          ivl_dental_plan_ids_2019,
          benefit_eligibility_element_group: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup.new(
              market_places:        ["individual"],
              enrollment_periods:   ["open_enrollment", "special_enrollment"],
              family_relationships: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup::INDIVIDUAL_MARKET_RELATIONSHIP_CATEGORY_KINDS,
              benefit_categories:   ["dental"],
              incarceration_status: ["unincarcerated"],
              age_range:            0..0,
              citizenship_status:   ["us_citizen", "naturalized_citizen", "alien_lawfully_present", "lawful_permanent_resident"],
              residency_status:     ["state_resident"],
              ethnicity:            ["any"]
            )
        )

        individual_catastrophic_health_benefit_package = ::IvlBenefitSponsors::IvlBenefitPackages::IvlBenefitPackage.new(
          title: "catastrophic_health_benefits_2019",
          elected_premium_credit_strategy: "unassisted",
          benefit_ids:          ivl_and_cat_health_plan_ids_2019,
          benefit_eligibility_element_group: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup.new(
            market_places:        ["individual"],
            enrollment_periods:   ["open_enrollment", "special_enrollment"],
            family_relationships: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup::INDIVIDUAL_MARKET_RELATIONSHIP_CATEGORY_KINDS,
            benefit_categories:   ["health"],
            incarceration_status: ["unincarcerated"],
            age_range:            0..30,
            citizenship_status:   ["us_citizen", "naturalized_citizen", "alien_lawfully_present", "lawful_permanent_resident"],
            residency_status:     ["state_resident"],
            ethnicity:            ["any"]
          )
        )

        native_american_health_benefit_package = ::IvlBenefitSponsors::IvlBenefitPackages::IvlBenefitPackage.new(
          title: "native_american_health_benefits_2019",
          elected_premium_credit_strategy: "unassisted",
          benefit_ids:          ivl_health_plan_ids_2019,
          benefit_eligibility_element_group: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup.new(
            market_places:        ["individual"],
            enrollment_periods:   ["open_enrollment", "special_enrollment"],
            family_relationships: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup::INDIVIDUAL_MARKET_RELATIONSHIP_CATEGORY_KINDS,
            benefit_categories:   ["health"],
            incarceration_status: ["unincarcerated"],
            age_range:            0..0,
            citizenship_status:   ["us_citizen", "naturalized_citizen", "alien_lawfully_present", "lawful_permanent_resident"],
            residency_status:     ["state_resident"],
            ethnicity:            ["indian_tribe_member"]
          )
        )

        native_american_dental_benefit_package = ::IvlBenefitSponsors::IvlBenefitPackages::IvlBenefitPackage.new(
          title: "native_american_dental_benefits_2019",
          elected_premium_credit_strategy: "unassisted",
          benefit_ids:          ivl_dental_plan_ids_2019,
          benefit_eligibility_element_group: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup.new(
            market_places:        ["individual"],
            enrollment_periods:   ["any"],
            family_relationships: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup::INDIVIDUAL_MARKET_RELATIONSHIP_CATEGORY_KINDS,
            benefit_categories:   ["dental"],
            incarceration_status: ["unincarcerated"],
            age_range:            0..0,
            citizenship_status:   ["us_citizen", "naturalized_citizen", "alien_lawfully_present", "lawful_permanent_resident"],
            residency_status:     ["state_resident"],
            ethnicity:            ["indian_tribe_member"]
          )
        )

        individual_health_benefit_package_for_csr_100 = ::IvlBenefitSponsors::IvlBenefitPackages::IvlBenefitPackage.new(
          title: "individual_health_benefits_csr_100_2019",
          elected_premium_credit_strategy: "allocated_lump_sum_credit",
          benefit_ids:          ivl_health_plan_ids_2019_for_csr_100,
          benefit_eligibility_element_group: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup.new(
            market_places:        ["individual"],
            enrollment_periods:   ["open_enrollment", "special_enrollment"],
            family_relationships: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup::INDIVIDUAL_MARKET_RELATIONSHIP_CATEGORY_KINDS,
            benefit_categories:   ["health"],
            incarceration_status: ["unincarcerated"],
            age_range:            0..0,
            cost_sharing:         "csr_100",
            citizenship_status:   ["us_citizen", "naturalized_citizen", "alien_lawfully_present", "lawful_permanent_resident"],
            residency_status:     ["state_resident"],
            ethnicity:            ["any"]
          )
        )

        individual_health_benefit_package_for_csr_94 = ::IvlBenefitSponsors::IvlBenefitPackages::IvlBenefitPackage.new(
          title: "individual_health_benefits_csr_94_2019",
          elected_premium_credit_strategy: "allocated_lump_sum_credit",
          benefit_ids:          ivl_health_plans_2019_for_csr_94,
          benefit_eligibility_element_group: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup.new(
            market_places:        ["individual"],
            enrollment_periods:   ["open_enrollment", "special_enrollment"],
            family_relationships: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup::INDIVIDUAL_MARKET_RELATIONSHIP_CATEGORY_KINDS,
            benefit_categories:   ["health"],
            incarceration_status: ["unincarcerated"],
            age_range:            0..0,
            cost_sharing:         "csr_94",
            citizenship_status:   ["us_citizen", "naturalized_citizen", "alien_lawfully_present", "lawful_permanent_resident"],
            residency_status:     ["state_resident"],
            ethnicity:            ["any"]
          )
        )

        individual_health_benefit_package_for_csr_87 = ::IvlBenefitSponsors::IvlBenefitPackages::IvlBenefitPackage.new(
          title: "individual_health_benefits_csr_87_2019",
          elected_premium_credit_strategy: "allocated_lump_sum_credit",
          benefit_ids:          ivl_health_plans_2019_for_csr_87,
          benefit_eligibility_element_group: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup.new(
            market_places:        ["individual"],
            enrollment_periods:   ["open_enrollment", "special_enrollment"],
            family_relationships: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup::INDIVIDUAL_MARKET_RELATIONSHIP_CATEGORY_KINDS,
            benefit_categories:   ["health"],
            incarceration_status: ["unincarcerated"],
            age_range:            0..0,
            cost_sharing:         "csr_87",
            citizenship_status:   ["us_citizen", "naturalized_citizen", "alien_lawfully_present", "lawful_permanent_resident"],
            residency_status:     ["state_resident"],
            ethnicity:            ["any"]
          )
        )

        individual_health_benefit_package_for_csr_73 = BenefitPackage.new(
          title: "individual_health_benefits_csr_73_2019",
          elected_premium_credit_strategy: "allocated_lump_sum_credit",
          benefit_ids:          ivl_health_plans_2019_for_csr_73,
          benefit_eligibility_element_group: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup.new(
            market_places:        ["individual"],
            enrollment_periods:   ["open_enrollment", "special_enrollment"],
            family_relationships: ::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup::INDIVIDUAL_MARKET_RELATIONSHIP_CATEGORY_KINDS,
            benefit_categories:   ["health"],
            incarceration_status: ["unincarcerated"],
            age_range:            0..0,
            cost_sharing:         "csr_73",
            citizenship_status:   ["us_citizen", "naturalized_citizen", "alien_lawfully_present", "lawful_permanent_resident"],
            residency_status:     ["state_resident"],
            ethnicity:            ["any"]
          )
        )

        bc_period_2019.benefit_packages = [
            individual_health_benefit_package,
            individual_dental_benefit_package,
            individual_catastrophic_health_benefit_package,
            native_american_health_benefit_package,
            native_american_dental_benefit_package,
            individual_health_benefit_package_for_csr_100,
            individual_health_benefit_package_for_csr_94,
            individual_health_benefit_package_for_csr_87,
            individual_health_benefit_package_for_csr_73
          ]

        bc_period_2019.save!
      end
    end
  end
end