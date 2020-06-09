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
            ['employee', 'domestic_partner']
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
    puts('Executing Golden Seed SHOP migration.')
    raise("No site present. Please load a site to the database.") if site.blank?
    carriers_plans_and_employee_dependent_count('health').each do |carrier_name, plan_list|
      plan_name_counter = 1
      plan_list.each do |plan_name, family_structure_list|
        family_structure_list.each_with_index do |family_structure, counter_number|
          counter_number = counter_number + 1
          family_structure_counter = 1
          plan_name_counter = plan_name_counter + 1
          employer_profile = initialize_and_return_employer_profile(counter_number + plan_name_counter)
          family_structure_counter = family_structure_counter + plan_name_counter + 1
          employer = create_and_return_new_employer(family_structure_counter, employer_profile)
          benefit_sponsorship = create_or_return_benefit_sponsorship(employer)
          benefit_application = create_and_return_benefit_application(benefit_sponsorship)
          #benefit_package_params = create_benefit_package_params(benefit_application)
          #benefit_package = create_and_return_benefit_package(benefit_package_params)
          employee_records = generate_and_return_employee_records(employer)
          family_structure.each do |relationship_kind|
            unless relationship_kind == "employee"
              primary_person = employee_records[:primary_person]
              generate_and_return_dependent_records(primary_person, relationship_kind, carrier_name)
            end
          end
        end
      end
    end
    puts("Golden Seed SHOP migration complete.")
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
    employee_role.person.ssn = person.ssn
    employee_role.person.gender = person.gender
    employee_role.person.dob = person.dob
    employee_role.hired_on = Date.today
    employee_role.save!
    employee_role
  end
  
  # TODO: Needs benefit packages for
  #   def active_benefit_group_assignment=(benefit_package_id) (census_employee.rb#601)
  # def create_and_return_census_employee(employee_role)
  #  ce = CensusEmployee.new
  #  ce.first_name = employee_role.person.first_name
  #  ce.last_name = employee_role.person.last_name
  #  ce.dob = employee_role.dob
  #  ce.ssn = employee_role.ssn
  #  ce.gender = employee_role.person.gender
  #  ce.hired_on = employee_role.hired_on
  #  ce.employer_profile_id = employee_role.employer_profile.id
  #  ce.benefit_sponsors_employer_profile_id = employee_role.employer_profile.id
  #  ce.save!
  # end

  def generate_and_return_employee_records(employer)
    genders = ['male', 'female']
    gender = genders.sample
    first_name = FFaker::Name.send("first_name_" + gender)
    last_name = FFaker::Name.last_name
    primary_person = create_and_return_person(first_name, last_name, gender)
    family = create_and_return_family(primary_person)
    user = create_and_return_user(primary_person)
    employee_role = create_and_return_employee_role(employer, primary_person)
    # TODO: Census Employee
    {
      family: family,
      primary_person: primary_person,
      user: user,
      employee_role: employee_role
    }
  end

  def generate_and_return_dependent_records(primary_person, personal_relationship_kind, carrier_name)
    genders = ['male', 'female']
    gender = genders.sample
    first_name = FFaker::Name.send("first_name_" + gender)
    last_name = primary_person.last_name
    family = primary_person.primary_family
    case personal_relationship_kind
    when 'child'
      dependent_person = create_and_return_person(first_name, last_name, gender, 'child')
    when 'domestic_partner'
      dependent_person = create_and_return_person(first_name, last_name, gender, 'adult')
    when 'spouse'
      dependent_person = create_and_return_person(first_name, last_name, gender, 'adult')
    end
    fm = FamilyMember.new(
      family: family,
      person_id: dependent_person.id,
      is_primary_applicant: false
    )
    fm.save!
    primary_person.person_relationships.create!(kind: personal_relationship_kind, relative_id: dependent_person.id)
    {
      dependent_person: dependent_person,
      dependent_family_member: fm
    }
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
    benefit_sponsorship.save!
    benefit_sponsorship.reload
    benefit_sponsorship.benefit_applications.last
  end


  def create_and_return_benefit_package(create_benefit_package_params)
    benefit_package = ::BenefitSponsors::Forms::BenefitPackageForm.for_create(create_benefit_package_params)
    if benefit_package.persist
      benefit_package
    end
  end

  def create_benefit_package_params(benefit_application)
    {
      benefit_application_id: benefit_application.id,
      title: "Benefit Package for Employer " + benefit_application.benefit_sponsorship.organization.legal_name,
      probation_period_kind: ::BenefitMarkets::PROBATION_PERIOD_KINDS.sample, # TODO: Need to know realistically what this might look like
      sponsored_benefits_attributes: [
        {
          kind: :health,
          product_package_kind: :single_product,
          reference_plan_id: '',
          sponsor_contribution_attributes: {
            contribution_levels_attributes: []
          }
        }
      ]
    }
  end

  def benefit_package_params
        params.require(:benefit_package).permit(
          :title, :description, :probation_period_kind, :benefit_application_id, :id,
          :sponsored_benefits_attributes => [:id, :kind, :product_option_choice, :product_package_kind, :reference_plan_id,
            :sponsor_contribution_attributes => [
              :contribution_levels_attributes => [:id, :is_offered, :display_name, :contribution_factor,:contribution_unit_id]
            ]
          ]
        )
      end

  def create_benefit_application_params(benefit_sponsorship)
    {
      start_on: benefit_application_start_on_end_on_dates[:coverage_start_on], # Required
      end_on: benefit_application_start_on_end_on_dates[:coverage_end_on], # Required
      open_enrollment_start_on: benefit_application_start_on_end_on_dates[:coverage_start_on], # Required
      open_enrollment_end_on: benefit_application_start_on_end_on_dates[:coverage_end_on], # Required
      fte_count: 0,
      pte_count: 0,
      msp_count: 0,
      benefit_packages: nil,
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
