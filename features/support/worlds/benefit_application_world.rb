module BenefitApplicationWorld

  def aasm_state
    @aasm_state ||= :active
  end

  def package_kind
    @package_kind ||= :single_issuer
  end

  def dental_sponsored_benefit(default=false)
    @dental_sponsored_benefit = default
  end

  def effective_period
    @effective_period ||= current_effective_date..current_effective_date.next_year.prev_day
  end

  def open_enrollment_start_on
    @open_enrollment_start_on ||= effective_period.min.prev_month
  end

  def open_enrollment_period
    @open_enrollment_period ||= open_enrollment_start_on..(effective_period.min - 10.days)
  end

  def service_areas
    @service_areas ||= benefit_sponsorship.service_areas_on(effective_period.min)
  end

  def initial_application
    @initial_application ||= BenefitSponsors::BenefitApplications::BenefitApplication.new(
        # benefit_sponsorship: benefit_sponsorship,
        benefit_sponsor_catalog: benefit_sponsor_catalog,
        effective_period: effective_period,
        aasm_state: aasm_state,
        open_enrollment_period: open_enrollment_period,
        recorded_rating_area: rating_area,
        recorded_service_areas: service_areas,
        fte_count: 5,
        pte_count: 0,
        msp_count: 0
    ).tap(&:save)
  end

  def roster_size(count=2)
    return count
  end

  def census_employees
    create_list(:census_employee, roster_size, :with_active_assignment, benefit_sponsorship: benefit_sponsorship, employer_profile: benefit_sponsorship.profile, benefit_group: current_benefit_package)
  end


  def dental_product_package
    @dental_product_package ||= initial_application.benefit_sponsor_catalog.product_packages.detect { |package| package.product_kind == :dental }
  end

  def current_benefit_package
    @current_benefit_package ||= FactoryGirl.create(:benefit_sponsors_benefit_packages_benefit_package,
      health_sponsored_benefit: false,
      dental_sponsored_benefit: false,
      product_package: find_product_package(:health, :single_issuer),
      dental_product_package: find_product_package(:dental, :single_issuer),
      benefit_application: initial_application
    )
  end

  def find_product_package(product_kind,package_kind)
    current_benefit_market_catalog.product_packages.find do |product_package|
      product_package.product_kind == product_kind &&
      product_package.package_kind == package_kind
    end
  end
end

World(BenefitApplicationWorld)

Given(/^this benefit application has a benefit package containing (?:both ?)(.*?)(?: and ?)(.*?) benefits$/) do |health, dental|
  health_products
  census_employees
  initial_application.benefit_packages = [current_benefit_package]
  benefit_sponsorship.benefit_applications = [initial_application]
  benefit_sponsorship.save!
  benefit_sponsor_catalog.save!
end
