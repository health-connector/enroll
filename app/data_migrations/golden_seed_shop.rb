require File.join(Rails.root, 'lib/mongoid_migration_task')

class GoldenSeedSHOP < MongoidMigrationTask
  def site
    @site = BenefitSponsors::Site.all.first
  end

  def ssns
    @ssns = []
  end

  def feins
    @feins = []
  end

  # Both fein and SSN have 9 numbers
  def generate_and_return_unique_fein_or_ssn(data_field)
    case data_field
    when 'fein'
      data_array = feins
      index_length = 8
    when 'ssn'
      data_array = ssns
      index_length = 8
    end
    return_value = SecureRandom.hex(100).tr('^0-9', '')[0..index_length]
    until data_array.exclude?(return_value)
      return_value = SecureRandom.hex(100).tr('^0-9', '')[0..index_length]
    end
    data_array << return_value
    return_value
  end

  def benefit_application_start_on_end_on_dates
    custom_coverage_start_on = ENV['coverage_start_on'].to_s
    custom_coverage_end_on = ENV['coverage_end_on'].to_s
    default_coverage_start_on = 2.months.from_now.at_beginning_of_month
    default_coverage_end_on = (default_coverage_start_on + 1.year)
    if custom_coverage_start_on.blank?
      @coverage_start_on = Date.strptime(default_coverage_start_on.to_s, "%m/%d/%Y")
    else
      @coverage_start_on = Date.strptime(custom_coverage_start_on, "%m/%d/%Y")
    end
    if custom_coverage_end_on.blank?
      # one year out from there
      @coverage_end_on = Date.strptime(default_coverage_end_on.to_s, "%m/%d/%Y")
    else
      @coverage_end_on = Date.strptime(custom_coverage_end_on, "%m/%d/%Y")
    end
    {
      coverage_start_on: @coverage_start_on,
      coverage_end_on: @coverage_end_on
    }
  end

  #### SOURCE DATA METHODS
  # TODO: Replace these with a source csv, with ruby friendly parameterized rows organized like so:
  # Health:
  # Health Carrier Name  Plan Name ER Name No: of EE with dependents Dob of EE/dependents  SIC Code  Zip Code  EE Only Spouse/Domestic partner Children  ER monthly cost - EA  Rate Calculator Premiums  EE Plan Confirmation page - EA  EE Rate Calculator Premiums Difference amount
  # Dental:
  # Dental Carrier Name  Plan Name ER Monthly cost - EA  Rate Calculator Premiums  EE Plan Confirmation page - EA  EE Rate Calculator Premiums Difference amount Status  Comments
  ### STRUCTURE OF HASH:
  #### Carrier Name
  ##### Plan Name
  ###### Family
  ####### 'employee' == employee, other strings == relationships to employee
  def carriers_plans_and_employee_dependent_count(kind)
    if kind == 'health'
      @health_carriers_plans_and_employee_dependent_count = {
        :'Tufts Health Premier' => {
          :'Tufts Health Premier Standard High Bronze: Premier Bronze Saver 3500' => [
            ['employee'],
            ['employee']
          ],
          :'STANDARD HIGH GOLD: PREMIER GOLD 1000' => [
            ['employee'],
            ['employee', 'domestic_partner', 'child']
          ]
        },
        :'BMC HEALTH NET PLAN' => {
          :'NON-STANDARD SILVER: BMC HEALTHNET PLAN SILVER B' => [
            ['employee'],
            ['employee', 'spouse', 'child']
          ]
        },
        :'Allways Health Partners' => {
          :'NON-STANDARD GOLD: COMPLETE HMO 2000 30%' => [
            ['employee', 'child', 'child'],
            ['employee', 'child', 'child', 'child']
          ]
        },
        :'Blue Cross Blue Shield' => {
          :'STANDARD HIGH BRONZE: HMO BLUE BASIC DEDUCTIBLE' => [
            ['employee'],
            ['employee', 'domestic_partner', 'child']
          ],
          :'STANDARD HIGH SILVER: HMO BLUE BASIC' => [
            ['employee'],
            ['employee', 'child', 'child', 'child', 'child'],
            ['employee', 'spouse'],
            ['employee, domestic_partner']
          ]
        },
        :'Tufts Health Direct' => {
          :'NON-STANDARD BRONZE: TUFTS HEALTH DIRECT BRONZE 3550 WITH COINSURANCE' => [
            ['employee'],
            ['employee', 'child', 'child', 'child', 'child'],
            ['employee', 'spouse'],
            ['employee', 'domestic_partner']
          ]
        },
        :'UHC' => {
          :'STANDARD LOW GOLD: UHC NAVIGATE GOLD 2000' => [['employee'], ['employee']]
        },
        :'Harvard Pilgrim' => {
          :'STANDARD LOW GOLD - FLEX' => [
            ['employee'],
            ['employee', 'spouse', 'child']
          ]
        },
        :'Fallon Health' => {
          :'NON-STANDARD GOLD: SELECT CARE DEDUCTIBLE 2000 HYBRID' => [
            ['employee', 'child', 'child'],
            ['employee', 'child', 'child', 'child']
          ]
        },
        :'Health New England' => {
          :'STANDARD HIGH SILVER: HNE SILVER A' => [
            ['employee'],
            ['employee', 'domestic_partner', 'child']
          ]
        }
      }
    else
      # Dental
    end
  end

  def migrate
    puts('Executing Golden Seed SHOP migration.') unless Rails.env.test?
    raise("No site present. Please load a site to the database.") if site.blank?
    carriers_plans_and_employee_dependent_count('health').each do |carrier_name, plan_list|
      plan_name_counter = 1
      plan_list.each do |plan_name, family_structure_list|
        family_structure_list.each_with_index do |family_structure, counter_number|
          #puts("family structure is " + family_structure.to_s)
          counter_number = counter_number + 1
          family_structure_counter = 1
          plan_name_counter = plan_name_counter + 1
          # TODO: Should be creating an employer every family. Is only creating 6.
          employer_profile = initialize_and_return_employer_profile(counter_number + plan_name_counter)
          family_structure_counter = family_structure_counter + plan_name_counter + 1
          employer = create_and_return_new_employer(family_structure_counter, employer_profile)
          benefit_sponsorship = create_or_return_benefit_sponsorship(employer)
          benefit_application = create_and_return_benefit_application(benefit_sponsorship)
          generate_and_return_employee(employer)
          #person = census_employee.employee_role.person
          #family = person.primary_family
          #if family_structure.length > 1
          #  dependents_list = family_stucture.reject { |family_member| family_member == 'employee' }.each do |personal_relationship_kind|
          #    generate_and_return_dependents(family, personal_relatonship_kind)   
          #  end
          #åend
        end
      end
    end
    puts("Golden Seed SHOP migration complete.") unless Rails.env.test?
  end

  def generate_random_birthday(person_type)
    case person_type
    when 'adult'
      birthday = FFaker::Time.between(Date.new(1950, 01, 01), Date.new(2000, 01, 01))
    when 'child'
      birthday = FFaker::Time.between(Date.new(2005, 01, 01), Date.new(2020, 01, 01))
    end
    Date.strptime(birthday.to_s, "%m/%d/%Y")
  end

  def create_and_return_person(first_name, last_name, gender, person_type = 'adult')
    person = Person.new(
      first_name: first_name,
      last_name: last_name,
      gender: gender,
      ssn: generate_and_return_unique_fein_or_ssn('ssn'),
      dob: generate_random_birthday(person_type)
    )
    person.save!
    person
  end

  def create_and_return_family(primary_person)
    family = Family.new
    family.person_id = primary_person.id
    fm = family.family_members.build(
      person_id: primary_person.id,
      is_primary_applicant: true
    )
    fm.save!
    family.save!
    family
  end

  def create_and_return_user(person)
    providers = ["gmail", "yahoo", "hotmail"]
    email = person.first_name + person.last_name + "@#{providers.sample}.com"
    user = User.new
    user.email = email
    user.oim_id = email
    user.password = "P@ssw0rd!"
    user.person = person
    user.save!
    user
  end

  def create_and_return_employee_role(employer, person)
    employee_role = person.employee_roles.build
    employee_role.employer_profile_id = employer.employer_profile.id
    employee_role.benefit_sponsors_employer_profile_id = employer.employer_profile.benefit_sponsorships.last.id
    employee_role.ssn = person.ssn
    employee_role.gender = person.gender
    employee_role.dob = person.dob
    employee_role.hired_on = Date.today
    employee_role.save!
    employee_role
  end

  def generate_and_return_employee(employer)
    genders = ['male', 'female']
    gender = genders.sample
    first_name = FFaker::Name.send("first_name_" + gender)
    last_name = FFaker::Name.last_name
    primary_person = create_and_return_person(first_name, last_name, gender)
    family = create_and_return_family(primary_person)
    create_and_return_user(primary_person)
    create_and_return_employee_role(employer, primary_person)
    # Create employee role - ignore this for now since we don't have employers yet
    # Create census employee (associate with employee role) - maybe ignore this for now since no employee roles
    # return census employee - ignore this for now
  end

  def generate_and_return_dependent(family, personal_relationship_kind)
    # maybe make this a case?
    # case personal_relationship_kind
    # when 'child'
    ## Create person
    ## create family member
    ## create relationships with person
    ## return person ?
  end

  def generate_address_and_phone(counter_number)
    address = Address.new(
      kind: "primary",
      address_1: "60" + counter_number.to_s + ('a'..'z').to_a.sample + ' ' + ['Street', 'Ave', 'Drive'].sample,
      city: "Boston",
      state: "MA",
      zip: "02109",
      county: "Suffolk"
    )
    phone = Phone.new(
      kind: "main",
      area_code: %w[339 351 508 617 774 781 857 978 413].sample,
      number: "55" + counter_number.to_s.split("").sample + "-999" + counter_number.to_s.split("").sample
    )
    [address, phone]
  end

  def generate_office_location(address_and_phone)
    OfficeLocation.new(
      is_primary: true,
      address: address_and_phone[0],
      phone: address_and_phone[1]
    )
  end

  def initialize_and_return_employer_profile(counter_number)
    address_and_phone = generate_address_and_phone(counter_number)
    office_location = generate_office_location(address_and_phone)
    employer_profile = BenefitSponsors::Organizations::AcaShopCcaEmployerProfile.new
    employer_profile.office_locations << office_location
    # sic_code required for MA only
    employer_profile.sic_code = '0111'
    employer_profile
  end

  # TODO: Figure out if we can user faker gem?
  def create_and_return_new_employer(counter_number, employer_profile)
    company_name = "Golden Seed" + ' ' + counter_number.to_s
    employer = BenefitSponsors::Organizations::GeneralOrganization.new(
      site: site,
      legal_name: company_name,
      dba: company_name + " " + ["Inc.", "LLC"].sample,
      fein: generate_and_return_unique_fein_or_ssn('fein'),
      profiles: [employer_profile],
      entity_kind: :c_corporation
    )
    employer.save!
    employer
  end

  def create_and_return_benefit_application(benefit_sponsorship)
    create_ba_params = create_benefit_application_params(benefit_sponsorship)
    ba_form = ::BenefitSponsors::Forms::BenefitApplicationForm.for_create(create_ba_params)
    ba_form.persist
    benefit_sponsorship.benefit_applications.last
  end

  # TODO: Potentially add arguements here to pass the FTE and other info
  # TODO: Create benefit packages
  def create_benefit_application_params(benefit_sponsorship)
    {
      start_on: benefit_application_start_on_end_on_dates[:coverage_start_on], # Required
      end_on: benefit_application_start_on_end_on_dates[:coverage_end_on], # Required
      open_enrollment_start_on: benefit_application_start_on_end_on_dates[:coverage_start_on], # Required
      open_enrollment_end_on: benefit_application_start_on_end_on_dates[:coverage_end_on], # Required
      fte_count: 0,
      pte_count: 0,
      msp_count: 0,
      benefit_packages: nil, #Array[::BenefitSponsors::Forms::BenefitPackageForm],
      id: "",
      benefit_sponsorship_id: benefit_sponsorship.id,
      start_on_options: {},
      admin_datatable_action: false,
    }
  end

  def create_or_return_benefit_sponsorship(employer)
    if employer.employer_profile.benefit_sponsorships.present?
      employer.benefit_sponsorships.last
    else
      employer.employer_profile.add_benefit_sponsorship.save!
      employer.benefit_sponsorships.last
    end
  end

  def generate_and_return_hbx_enrollment(primary_family, aasm_state: nil)

  end
end
