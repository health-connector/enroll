module BenefitApplicationWorld

  def aasm_state(key=nil)
    @aasm_state ||= key
  end

  def renewal_state(key = nil)
    @renewal_state ||= key
  end

  def health_state(key=false)
    @health_state ||= key
  end

  def dental_state(key=false)
    @dental_state ||= key
  end

  def package_kind
    @package_kind ||= :single_issuer
  end

  def dental_package_kind
    @dental_package_kind ||= :single_product
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

  def sic_code
    @sic_code ||= benefit_sponsorship.sic_code
  end

  def initial_application
    @initial_application ||= BenefitSponsors::BenefitApplications::BenefitApplication.new(
        benefit_sponsorship: benefit_sponsorship,
        benefit_sponsor_catalog: benefit_sponsor_catalog,
        effective_period: effective_period,
        aasm_state: aasm_state,
        open_enrollment_period: open_enrollment_period,
        recorded_rating_area: rating_area,
        recorded_service_areas: service_areas,
        recorded_sic_code: sic_code,
        fte_count: 5,
        pte_count: 0,
        msp_count: 0
    ).tap(&:save)
  end

  def benefit_application_by_employer(organization)
    @current_application ||= BenefitSponsors::BenefitApplications::BenefitApplication.find_or_initialize_by(
        benefit_sponsorship: benefit_sponsorship(organization),
        benefit_sponsor_catalog: benefit_sponsor_catalog(organization),
        effective_period: effective_period,
        aasm_state: aasm_state,
        open_enrollment_period: open_enrollment_period,
        recorded_rating_area: rating_area,
        recorded_service_areas: service_areas,
        recorded_sic_code: sic_code,
        fte_count: 5,
        pte_count: 0,
        msp_count: 0
    ).tap(&:save)
  end

  def new_benefit_package_by_application(current_application)
    @new_benefit_package_by_application ||= FactoryGirl.create(
      :benefit_sponsors_benefit_packages_benefit_package,
      benefit_application: current_application,
      product_package: find_product_package(:health, :single_issuer),
      dental_product_package: find_product_package(:dental, :single_issuer)
    )
  end

  def renewal_application
    @renewal_application ||= FactoryGirl.build(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog,
                                               :with_benefit_package, :with_predecessor_application,
                                               predecessor_application_state: aasm_state,
                                               benefit_sponsorship: benefit_sponsorship,
                                               effective_period: effective_period,
                                               aasm_state: renewal_state,
                                               open_enrollment_period: open_enrollment_period,
                                               recorded_rating_area: rating_area,
                                               recorded_service_areas: service_areas,
                                               package_kind: package_kind,
                                               dental_package_kind: dental_package_kind,
                                               dental_sponsored_benefit: dental_sponsored_benefit,
                                               predecessor_application_catalog: true)
  end

  def assign_sponsored_benefits
  product_package = benefit_market.benefit_market_catalogs.first.product_packages.where(package_kind: :single_issuer).first

  end

  def roster_size(count=5)
    return count
  end

  def census_employees_roster
    @employees ||= create_list(:census_employee, roster_size, :with_active_assignment, benefit_sponsorship: benefit_sponsorship, employer_profile: benefit_sponsorship.profile, benefit_group: current_benefit_package)
  end

  def new_benefit_package
    FactoryGirl.create(:benefit_sponsors_benefit_packages_benefit_package, benefit_application: initial_application, product_package: find_product_package(:health, :single_issuer), dental_product_package: find_product_package(:dental, :single_issuer), dental_sponsored_benefit: true)
  end

  def ce
    create_list(:census_employee, 1 , :with_active_assignment, first_name: "Patrick", last_name: "Doe", dob: "1980-01-01".to_date, ssn: "786120965", benefit_sponsorship: benefit_sponsorship, employer_profile: benefit_sponsorship.profile, benefit_group: initial_application.benefit_packages.first)
  end

  def premium_tuples
    create_list(:benefit_markets_products_premium_tuple, 3)
  end

  def dental_product_package
    @dental_product_package ||= initial_application.benefit_sponsor_catalog.product_packages.detect { |package| package.product_kind == :dental }
  end

  def current_benefit_package
    @current_benefit_package ||= FactoryGirl.create(:benefit_sponsors_benefit_packages_benefit_package,
      health_sponsored_benefit: health_state,
      dental_sponsored_benefit: dental_state,
      product_package: find_product_package(:health, :single_issuer),
      dental_product_package: find_product_package(:dental, :single_issuer),
      benefit_application: initial_application
    ).tap do |benefit_package|

    end
  end

  def new_benefit_package
    FactoryGirl.create(:benefit_sponsors_benefit_packages_benefit_package, benefit_application: initial_application, product_package: find_product_package(:health, :single_issuer), dental_product_package: find_product_package(:dental, :single_issuer))
  end

  def find_product_package(product_kind,package_kind)
    current_benefit_market_catalog.product_packages.detect do |product_package|
      product_package.product_kind == product_kind &&
      product_package.package_kind == package_kind
    end
  end

  def update_benefit_sponsorship
    health_products
    census_employees_roster
    initial_application.benefit_packages = [current_benefit_package]
    benefit_sponsorship.benefit_applications = [initial_application]
    benefit_sponsorship.benefit_applications.first.update(created_at:Date.today)
    benefit_sponsorship.save!
    benefit_sponsor_catalog.save!
  end


  def properly_associate_benefit_package
    initial_application.open_enrollment_period = TimeKeeper.date_of_record..TimeKeeper.date_of_record + 19.days
    initial_application.benefit_packages = [new_benefit_package]
    @census_employees ||= create_list(:census_employee, roster_size, :with_active_assignment, benefit_sponsorship: benefit_sponsorship, employer_profile: benefit_sponsorship.profile, benefit_group: initial_application.benefit_packages.first)
  end
end

World(BenefitApplicationWorld)

Given(/^this employer has not setup a benefit application$/) do
  health_products
  census_employees_roster
  initial_application.benefit_packages = [current_benefit_package]
  benefit_sponsorship.save!
  benefit_sponsor_catalog.save!
end

And(/^this employer has a benefit application$/) do
  # This should be re-factored such that properly create a active application
  health_products
  initial_application.update_attributes(aasm_state: :enrollment_open)
  initial_application.benefit_packages = [new_benefit_package]
  benefit_sponsorship.save!
  benefit_sponsor_catalog.save!
end

And(/^this employer had a (.*?)(?: and (.*?) (.*?))? application$/) do |active_app, renewal_app, renewal_state|

  renewal_state = renewal_state.present? ? renewal_state.to_sym : :draft
  if renewal_app
    aasm_state(:active)
    renewal_state(renewal_state)
    renewal_application
  elsif active_app
    # Fix for active application
  end
end

And(/^this employer offering (.*?) contribution to (.*?)$/) do |percent, display_name|
  benefit_sponsorship.benefit_applications.each do |application|
    application.benefit_packages.each do |benefit_package|
      benefit_package.sponsored_benefits.each do |sponsored_benefit|
        next unless sponsored_benefit.sponsor_contribution.present?
        sponsored_benefit.sponsor_contribution.contribution_levels.each do |contribution_level|
          next unless contribution_level.display_name == display_name
          contribution_level.update_attributes(contribution_factor: percent)
        end
      end
    end
  end
end

And(/this employer (.*) has (.*) rule/) do |legal_name, rule|
  employer_profile = employer_profile(legal_name)
  employer_profile.active_benefit_sponsorship.benefit_applications.each do |benefit_application|
    benefit_application.benefit_packages.each{|benefit_package| benefit_package.update_attributes(probation_period_kind: rule.to_sym) }
  end
end

And(/^this employer has enrollment_open benefit application with offering health and dental$/) do
  aasm_state(:enrollment_open)
  initial_application.benefit_packages = [new_benefit_package]
  benefit_sponsorship.benefit_applications << initial_application
  ce
  benefit_sponsorship.organization.update_attributes!(fein: "764141112")
  benefit_sponsorship.save!
  benefit_sponsor_catalog.save!
end

And(/^has a draft application$/) do
  # This should be re-factored such that properly create a active application
  health_products
  properly_associate_benefit_package
  benefit_sponsorship.save!
  benefit_sponsor_catalog.save!
end

And(/^(.*?) employer visit the benefits tab$/) do |legal_name|
  organization = @organization[legal_name]
  employer_profile = organization.employer_profile
  visit benefit_sponsors.profiles_employers_employer_profile_path(employer_profile.id, :tab => 'benefits')
end

Then(/^(.*?) should be able to set up benefit aplication$/) do |legal_name|
  find(:xpath, "//p[@class='label'][contains(., 'SELECT START ON')]", :wait => 3).click
  find(:xpath, "//li[@data-index='1'][contains(., '#{(Date.today + 2.months).year}')]", :wait => 3).click

  find('.interaction-field-control-fteemployee').click
  fill_in 'benefit_application[fte_count]', with: '3'
  fill_in 'benefit_application[pte_count]', with: '3'
  fill_in 'benefit_application[msp_count]', with: '3'

  find('.interaction-click-control-continue').click
  sleep(3)

end

Then(/^Employer visit the benefits page$/) do
  click_link 'Benefits'
end

And(/^Employer creates Benefit package$/) do
  wait_for_ajax
  fill_in 'benefit_package[title]', with: 'Silver PPO Group'
  fill_in 'benefit_package[description]', with: 'Testing'
  find(:xpath, '//*[@id="metal-level-select"]/div/ul/li[1]/a').click
  wait_for_ajax
  find(:xpath, '//*[@id="carrier"]/div[1]/div/label').click
  sleep 5
  wait_for_ajax
end

And(/^this employer has a (.*?) benefit application$/) do |status|
  case status
  when "published"
    aasm_state(:published)
  when "draft"
    aasm_state(:draft)
  when "active"
    aasm_state(:active)
  when "canceled"
    aasm_state(:canceled)
  when "enrollment_closed"
    aasm_state(:enrollment_closed)
  when "enrollment_eligible"
    aasm_state(:enrollment_eligible)
  when "enrollment_extended"
    aasm_state(:enrollment_extended)
  when "enrollment_ineligible"
    aasm_state(:enrollment_ineligible)
  when "enrollment_open"
    aasm_state(:enrollment_open)
  when "expired"
    aasm_state(:expired)
  when "imported"
    aasm_state(:imported)
  when "pending"
    aasm_state(:pending)
  when "terminated"
    aasm_state(:terminated)
  when "termination_pending"
    aasm_state(:termination_pending)
  end
end

And(/^this benefit application has a benefit package containing (.*?)(?: and (.*?))? benefits$/) do |health, dental|
  if health == "health"
    health_state(true)
  end
  if dental == "dental"
    dental_state(true)
  end
  update_benefit_sponsorship
end

And(/^employer (.*?) has a (.*?) benefit application with offering health and dental$/) do |legal_name, state|
  health_products
  aasm_state(state.to_sym)
  organization = @organization[legal_name]
  # Mirrors the original step minus the census employee declaration
  current_application = benefit_application_by_employer(organization)
  current_package = new_benefit_package_by_application(current_application)
  current_sponsorship = benefit_sponsorship(organization)

  current_application.benefit_packages << current_package
  current_application.save!
  current_sponsorship.benefit_applications << current_application
  current_sponsorship.save!
  current_catalog = benefit_sponsor_catalog(organization)
  current_catalog.save!
  expect(current_application.benefit_packages.present?).to eq(true)
  expect(current_sponsorship.benefit_applications.present?).to eq(true)
end

And(/^employer (.*?) has a census employee (.*?)$/) do |legal_name, named_person|
  person = people[named_person]
  create_census_employee_from_person(person)
end

And(/^census employee (.*?) has a person and user record$/) do |named_person|
  person = people[named_person]
  create_person_and_user_from_census_employee(person)
end
