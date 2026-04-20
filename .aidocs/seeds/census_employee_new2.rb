# frozen_string_literal: true
# Creates a brand-new census employee under an existing employer+package.
# Uses a direct MongoDB collection insert to bypass the after_create callback
# (CensusEmployee#assign_benefit_packages) which errors on new records.
#
# ENV vars:
#   PROFILE_ID   - employer profile BSON id (required)
#   PACKAGE_ID   - benefit package BSON id (required)
#   QA_FIRST     - first name   (default: Jane)
#   QA_LAST      - last name    (default: NewEmployee)
#   QA_SSN       - SSN digits only, no dashes (default: 098765432)
#   QA_EMAIL     - employee login email (default: jane.newemployee@example.com)
#   QA_DOB       - YYYY-MM-DD  (default: 1988-06-20)
#   QA_HIRED     - YYYY-MM-DD  (default: 2026-01-01)

load File.join(__dir__, 'helpers.rb')

profile_id = BSON::ObjectId(ENV.fetch('PROFILE_ID'))
package_id = BSON::ObjectId(ENV.fetch('PACKAGE_ID'))
profile    = BenefitSponsors::Organizations::AcaShopCcaEmployerProfile.find(profile_id)
pkg        = BenefitSponsors::BenefitPackages::BenefitPackage.find(package_id)

first_name = ENV.fetch('QA_FIRST',  'Jane')
last_name  = ENV.fetch('QA_LAST',   'NewEmployee')
ssn_raw    = ENV.fetch('QA_SSN',    '098765432').gsub(/\D/, '')
email      = ENV.fetch('QA_EMAIL',  'jane.newemployee@example.com')
dob        = Date.parse(ENV.fetch('QA_DOB',   '1988-06-20'))
hired_on   = Date.parse(ENV.fetch('QA_HIRED', '2026-01-01'))
now        = Time.now

puts "=== QA Seed: New Census Employee (direct insert) ==="
puts "Employer: #{profile.organization.legal_name}"
puts "Package:  #{pkg.title}"

ce_id = BSON::ObjectId.new

# Build the Mongoid-compatible document, bypassing all callbacks
raw_doc = {
  '_id'                                    => ce_id,
  '_type'                                  => 'CensusEmployee',
  'first_name'                             => first_name,
  'last_name'                              => last_name,
  'dob'                                    => dob.to_time.utc,
  'hired_on'                               => hired_on.to_time.utc,
  'gender'                                 => 'female',
  'aasm_state'                             => 'eligible',
  'benefit_sponsors_employer_profile_id'   => profile_id,
  'benefit_sponsorship_id'                 => profile.active_benefit_sponsorship.id,
  'benefit_group_assignments'              => [],
  'addresses'                              => [{
    '_id'       => BSON::ObjectId.new,
    'kind'      => 'home',
    'address_1' => '200 Elm St',
    'city'      => 'Pittsfield',
    'state'     => 'MA',
    'zip'       => '01247'
  }],
  'emails' => [{
    '_id'     => BSON::ObjectId.new,
    'kind'    => 'home',
    'address' => email
  }],
  'created_at' => hired_on.to_time.utc,
  'updated_at' => now
}

CensusEmployee.collection.insert_one(raw_doc)
ce = CensusEmployee.where(_id: ce_id).first
raise "Insert failed — document not found" unless ce
puts "Inserted: #{ce.full_name} (#{ce.id})"

# Set SSN through the model's encrypted setter
ce.ssn = ssn_raw
ce.set(updated_at: now)
puts "SSN set (encrypted)"

# Backdate created_at so new_hire_enrollment_period is valid
QASeed.backdate_census_employee!(ce)

# Add BenefitGroupAssignment
bga_doc = {
  '_id'                => BSON::ObjectId.new,
  'benefit_package_id' => package_id,
  'start_on'           => [pkg.start_on, hired_on].compact.max.to_time.utc,
  'is_active'          => true,
  'aasm_state'         => 'coverage_selected',
  'created_at'         => hired_on.to_time.utc,
  'updated_at'         => now
}
CensusEmployee.collection.update_one(
  { '_id' => ce_id },
  { '$push' => { 'benefit_group_assignments' => bga_doc } }
)
puts "BGA added"

# Create employee User account
user = QASeed.find_or_create_user(
  email:      email,
  password:   'Password1!',
  first_name: first_name,
  last_name:  last_name,
  dob:        dob
)
puts "User: #{user.email}"

ssn_display = "#{ssn_raw[0..2]}-#{ssn_raw[3..4]}-#{ssn_raw[5..8]}"

QASeed.output(
  census_employee_id: ce.id.to_s,
  first_name:         first_name,
  last_name:          last_name,
  ssn:                ssn_display,
  dob:                dob.strftime('%m/%d/%Y'),
  hired_on:           hired_on.strftime('%m/%d/%Y'),
  employee_email:     email,
  employee_password:  'Password1!'
)
