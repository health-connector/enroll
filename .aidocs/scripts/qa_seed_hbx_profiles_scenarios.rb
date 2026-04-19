# frozen_string_literal: true

# QA Seed Script: HBX Admin Edit DOB/SSN Scenarios
#
# Usage:
#   bundle exec rails runner .aidocs/scripts/qa_seed_hbx_profiles_scenarios.rb
#
# Outputs JSON with credentials for Playwright browser tests:
#   { "admin_email": "...", "admin_password": "...", "employee_name": "...", "employee_ssn": "..." }
#
# Prerequisites: CCA site must be seeded first via db/seedfiles/cca/cca_seed.rb

require 'factory_bot_rails'

begin
  # Load FactoryBot factories if not already loaded
  FactoryBot.find_definitions unless FactoryBot.factories.count > 0
rescue => e
  # Factories may already be loaded
end

ADMIN_EMAIL = "hbxadmin_qa@example.com"
ADMIN_PASSWORD = "aA1!aA1!aA1!"
EMPLOYEE_FIRST = "Patrick"
EMPLOYEE_LAST = "Doe"
EMPLOYEE_SSN = "786120987"
EMPLOYEE_DOB = Date.new(1980, 1, 1)
EMPLOYER_LEGAL_NAME = "ACME Widgets, Inc."

# --- 1. Ensure Site & HBX Profile exist ---
site = BenefitSponsors::Site.all.first
unless site
  puts "ERROR: CCA site not found. Run 'bundle exec rails runner db/seedfiles/cca/cca_seed.rb' first."
  exit 1
end

hbx_profile = HbxProfile.current_hbx
unless hbx_profile
  org = Organization.where(legal_name: "#{EnrollRegistry[:enroll_app].setting(:short_name).item}").first
  org ||= FactoryBot.create(:organization, legal_name: EnrollRegistry[:enroll_app].setting(:short_name).item)
  hbx_profile = org.create_hbx_profile(
    cms_id: "DC0",
    us_state_abbreviation: EnrollRegistry[:enroll_app].setting(:state_abbreviation).item
  )
end

# --- 2. Create Permission with SSN update capability ---
permission = Permission.where(name: 'hbx_staff').first
unless permission
  permission = FactoryBot.create(:permission, :hbx_staff, :hbx_update_ssn)
end

# Ensure can_update_ssn is true
permission.update!(can_update_ssn: true) unless permission.can_update_ssn

# --- 3. Create HBX Admin user ---
admin_user = User.where(email: ADMIN_EMAIL).first
unless admin_user
  admin_person = FactoryBot.create(
    :person,
    first_name: "HBX",
    last_name: "Admin"
  )

  admin_person.build_hbx_staff_role(
    hbx_profile_id: hbx_profile.id,
    permission_id: permission.id,
    is_active: true,
    subrole: "hbx_staff"
  )
  admin_person.save!

  admin_user = FactoryBot.create(
    :user,
    email: ADMIN_EMAIL,
    password: ADMIN_PASSWORD,
    password_confirmation: ADMIN_PASSWORD,
    person: admin_person,
    roles: ["hbx_staff"]
  )
end

# --- 4. Create Employer Organization ---
employer_org = BenefitSponsors::Organizations::GeneralOrganization.where(legal_name: EMPLOYER_LEGAL_NAME).first
unless employer_org
  employer_profile = FactoryBot.create(
    :benefit_sponsors_organizations_general_organization,
    :with_aca_shop_cca_employer_profile,
    site: site,
    legal_name: EMPLOYER_LEGAL_NAME
  ).employer_profile rescue nil

  if employer_profile.nil?
    # Fallback: create manually
    employer_org = BenefitSponsors::Organizations::GeneralOrganization.create!(
      site: site,
      legal_name: EMPLOYER_LEGAL_NAME,
      fein: "#{rand(100_000_000..999_999_999)}",
      profiles: [BenefitSponsors::Organizations::AcaShopCcaEmployerProfile.new(
        sic_code: "0111"
      )]
    )
    employer_profile = employer_org.employer_profile
  else
    employer_org = employer_profile.organization
  end
end
employer_profile ||= BenefitSponsors::Organizations::GeneralOrganization.where(legal_name: EMPLOYER_LEGAL_NAME).first&.employer_profile

# --- 5. Create Census Employee for Patrick Doe ---
census_employee = CensusEmployee.where(first_name: EMPLOYEE_FIRST, last_name: EMPLOYEE_LAST).first
unless census_employee
  benefit_sponsorship = employer_profile.active_benefit_sponsorship || employer_profile.add_benefit_sponsorship
  census_employee = CensusEmployee.create!(
    first_name: EMPLOYEE_FIRST,
    last_name: EMPLOYEE_LAST,
    ssn: EMPLOYEE_SSN,
    dob: EMPLOYEE_DOB,
    gender: "male",
    employer_profile_id: employer_profile.id,
    benefit_sponsorship: benefit_sponsorship,
    hired_on: TimeKeeper.date_of_record - 1.year,
    employee_role_id: nil
  )
end

# --- 6. Create Employee Person & User ---
employee_person = Person.where(first_name: EMPLOYEE_FIRST, last_name: EMPLOYEE_LAST).first
unless employee_person
  employee_person = FactoryBot.create(
    :person,
    first_name: EMPLOYEE_FIRST,
    last_name: EMPLOYEE_LAST,
    ssn: EMPLOYEE_SSN,
    dob: EMPLOYEE_DOB
  )
end

# Create family for the employee
family = Family.where(:"family_members.person_id" => employee_person.id).first
unless family
  family = FactoryBot.create(:family, :with_primary_family_member, person: employee_person)
end

# --- 7. Output JSON credentials for Playwright ---
result = {
  admin_email: ADMIN_EMAIL,
  admin_password: ADMIN_PASSWORD,
  employee_name: "#{EMPLOYEE_FIRST} #{EMPLOYEE_LAST}",
  employee_ssn: EMPLOYEE_SSN,
  employee_dob: EMPLOYEE_DOB.to_s,
  employer_name: EMPLOYER_LEGAL_NAME,
  user_id: admin_user.id.to_s,
  person_id: employee_person.id.to_s,
  family_id: family.id.to_s
}

puts result.to_json
