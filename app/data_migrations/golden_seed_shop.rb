require File.join(Rails.root, 'lib/mongoid_migration_task')

class GoldenSeedSHOP < MongoidMigrationTask
  def site
    @site = BenefitSponsors::Site.all.first
  end

  def feins
    @feins = []
  end

  def generate_and_return_unique_fein
    fein = SecureRandom.hex(100).tr('^0-9', '')[0..8]
    until feins.exclude?(fein)
      fein = SecureRandom.hex(100).tr('^0-9', '')[0..8]
    end
    feins << fein
    fein
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
          create_or_return_benefit_sponsorship(employer)
          # census_employee = generate_and_return_employee(employer)
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

  def generate_and_return_employee(employer)
    # Create person
    # Create employee role
    # Create census employee (associate with employee role)
    # return census employee

  end

  def generate_and_return_dependent(family, personal_relationship_kind)
    # Create person
    # create family member
    # create relationships with person
    # return person ?
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
      fein: generate_and_return_unique_fein,
      profiles: [employer_profile],
      entity_kind: :c_corporation
    )
    employer.save!
    employer
  end

  def create_or_return_benefit_sponsorship(employer)
    if employer.employer_profile.benefit_sponsorships.present?
      employer.benefit_sponsorships.last
    else
      employer.employer_profile.add_benefit_sponsorship.save!
    end
  end

  def generate_and_return_hbx_enrollment(primary_family, aasm_state: nil)

  end
end
