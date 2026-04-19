# frozen_string_literal: true

# QA Seed: Census Employee Enrollable
#
# Creates a census employee on an existing employer profile that is fully ready for
# the employee enrollment flow:
#   - SSN, DOB, hired_on set as specified
#   - created_at backdated to hired_on (prevents new_hire_enrollment_period block)
#   - BenefitGroupAssignment to the active benefit package
#   - Linked employee User account (for sign-in + employer match)
#
# Usage:
#   PROFILE_ID=<id> PACKAGE_ID=<id> bundle exec rails runner .aidocs/seeds/census_employee_enrollable.rb
#
#   Optional ENV vars:
#     QA_EMPLOYEE_FIRST  — default: "John"
#     QA_EMPLOYEE_LAST   — default: "Employee"
#     QA_EMPLOYEE_SSN    — default: "012345678" (no dashes)
#     QA_EMPLOYEE_DOB    — default: "1990-01-15"
#     QA_EMPLOYEE_HIRED  — default: first day of current year
#     QA_EMPLOYEE_EMAIL  — default: "john.employee@example.com"
#     QA_EMPLOYEE_PASS   — default: "Password1!"
#
# Output JSON:
#   {
#     "census_employee_id": "<id>",
#     "first_name": "John",
#     "last_name": "Employee",
#     "ssn": "012-34-5678",
#     "dob": "1990-01-15",
#     "hired_on": "YYYY-MM-DD",
#     "employee_email": "...",
#     "employee_password": "..."
#   }

load File.join(__dir__, 'helpers.rb')

puts "=== QA Seed: Census Employee Enrollable ==="

# ── Config ─────────────────────────────────────────────────────────────────────

profile_id = ENV.fetch("PROFILE_ID") { abort "ERROR: Set PROFILE_ID env var" }
package_id = ENV.fetch("PACKAGE_ID") { abort "ERROR: Set PACKAGE_ID env var" }

first_name = ENV.fetch("QA_EMPLOYEE_FIRST", "John")
last_name  = ENV.fetch("QA_EMPLOYEE_LAST", "Employee")
ssn_raw    = ENV.fetch("QA_EMPLOYEE_SSN", "012345678").gsub(/\D/, "")
dob        = Date.parse(ENV.fetch("QA_EMPLOYEE_DOB", "1990-01-15"))
hired_on   = Date.parse(ENV.fetch("QA_EMPLOYEE_HIRED", Date.new(Date.today.year, 1, 1).to_s))
emp_email  = ENV.fetch("QA_EMPLOYEE_EMAIL", "john.employee@example.com")
emp_pass   = ENV.fetch("QA_EMPLOYEE_PASS", "Password1!")

# ── Load records ───────────────────────────────────────────────────────────────

profile = BenefitSponsors::Organizations::AcaShopCcaEmployerProfile.find(profile_id)
package = BenefitSponsors::BenefitPackages::BenefitPackage.find(package_id)

puts "Employer: #{profile.organization.legal_name}"
puts "Package: #{package.title}"

# ── 1. Create or find CensusEmployee ──────────────────────────────────────────

ce = CensusEmployee.where(
  benefit_sponsors_employer_profile_id: profile.id,
  first_name: first_name,
  last_name: last_name
).first

unless ce
  ce = CensusEmployee.new(
    benefit_sponsors_employer_profile_id: profile.id,
    employer_profile_id: profile.id,
    first_name: first_name,
    last_name: last_name,
    dob: dob,
    hired_on: hired_on,
    gender: "male",
    address: Address.new(
      kind: "home",
      address_1: "200 Elm St",
      city: "Pittsfield",
      state: "MA",
      zip: "01247"
    ),
    email: Email.new(kind: "home", address: emp_email)
  )
  # Set SSN via the encrypted setter
  ce.ssn = ssn_raw
  ce.save!(validate: false)
  puts "Created census employee: #{ce.full_name} (id: #{ce.id})"
else
  puts "Using existing census employee: #{ce.full_name} (id: #{ce.id})"
end

# ── 2. Backdate created_at = hired_on to fix new_hire_enrollment_period ────────

QASeed.backdate_census_employee!(ce)

# ── 3. Add BenefitGroupAssignment to the active package ───────────────────────

QASeed.assign_benefit_package!(profile, package)

# Reload after save
ce.reload

# ── 4. Create employee User account ───────────────────────────────────────────

emp_user = QASeed.find_or_create_user(
  email: emp_email,
  password: emp_pass,
  first_name: first_name,
  last_name: last_name,
  dob: dob
)

# Link EmployeeRole if not already set
if emp_user.person && ce.employee_role.nil?
  employee_role = emp_user.person.employee_roles.build(
    employer_profile_id: profile.id,
    benefit_sponsors_employer_profile_id: profile.id,
    hired_on: hired_on,
    is_active: true
  )
  emp_user.person.save!(validate: false)

  ce.employee_role_id = employee_role.id
  ce.save!(validate: false)
  puts "Linked EmployeeRole to census employee"
end

# ── Output ─────────────────────────────────────────────────────────────────────

QASeed.output(
  census_employee_id: ce.id.to_s,
  first_name: ce.first_name,
  last_name: ce.last_name,
  ssn: ssn_raw.sub(/^(\d{3})(\d{2})(\d{4})$/, '\1-\2-\3'),
  dob: ce.dob.to_s,
  hired_on: ce.hired_on.to_s,
  employee_email: emp_email,
  employee_password: emp_pass
)
