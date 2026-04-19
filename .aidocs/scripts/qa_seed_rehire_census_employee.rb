# Seed script for rehire census employee bug testing
# Uses existing Er1-Corp employer, terminates one employee, creates employer user
# Run: bundle exec rails runner .aidocs/scripts/qa_seed_rehire_census_employee.rb

require 'json'

puts "=== Seeding Rehire Census Employee Test Data ==="

# Use existing Er1-Corp employer
org = BenefitSponsors::Organizations::GeneralOrganization.where(legal_name: "Er1-Corp").first
abort "ERROR: Er1-Corp not found. Run main seed first." unless org

employer_profile = org.profiles.detect { |p| p.is_a?(BenefitSponsors::Organizations::AcaShopCcaEmployerProfile) }
abort "ERROR: No employer profile found on Er1-Corp." unless employer_profile

# Terminate one existing census employee (Maurice White)
census_employee = CensusEmployee.where(
  benefit_sponsors_employer_profile_id: employer_profile.id,
  first_name: "Maurice"
).first
abort "ERROR: Census employee Maurice not found." unless census_employee

terminated_on = Date.today - 30.days
coverage_terminated_on = terminated_on.end_of_month

census_employee.employment_terminated_on = terminated_on
census_employee.coverage_terminated_on = coverage_terminated_on
census_employee.aasm_state = "employment_terminated"
census_employee.save!(validate: false)

puts "Terminated: #{census_employee.first_name} #{census_employee.last_name}"
puts "  State: #{census_employee.aasm_state}"
puts "  employment_terminated_on: #{census_employee.employment_terminated_on}"
puts "  coverage_terminated_on: #{census_employee.coverage_terminated_on}"

# Create or find employer login user
employer_user = User.where(email: "employer_rehire_qa@example.com").first_or_create!(
  password: "aA1!aA1!aA1!",
  password_confirmation: "aA1!aA1!aA1!",
  approved: true
)

employer_person = employer_user.person
unless employer_person
  employer_person = Person.create!(
    first_name: "Employer",
    last_name: "Rehire",
    gender: "male",
    dob: Date.new(1975, 6, 15),
    user: employer_user
  )
end

# Add employer_staff_role if not present
unless employer_person.employer_staff_roles.where(benefit_sponsor_employer_profile_id: employer_profile.id).exists?
  employer_person.employer_staff_roles.create!(
    benefit_sponsor_employer_profile_id: employer_profile.id,
    aasm_state: "is_active"
  )
end

output = {
  employer_email: "employer_rehire_qa@example.com",
  employer_password: "aA1!aA1!aA1!",
  employer_profile_id: employer_profile.id.to_s,
  census_employee_id: census_employee.id.to_s,
  census_employee_name: "#{census_employee.first_name} #{census_employee.last_name}",
  employment_terminated_on: census_employee.employment_terminated_on.to_s,
  coverage_terminated_on: census_employee.coverage_terminated_on.to_s
}

puts "\n=== SEED OUTPUT ==="
puts output.to_json
