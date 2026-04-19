# frozen_string_literal: true

# QA Seed Helpers
#
# Shared utilities for all .aidocs/seeds/*.rb scripts.
# Usage: load File.join(__dir__, 'helpers.rb')
#
# Provides:
#   QASeed.output(data)              — prints JSON output block
#   QASeed.require_site!             — ensures CCA site exists
#   QASeed.find_or_create_user(...)  — user + person creation
#   QASeed.approve_attestation!(profile)
#   QASeed.assign_benefit_package!(profile, package)
#   QASeed.backdate_census_employee!(ce)

module QASeed
  # Print structured JSON output for downstream consumption by Playwright/scripts
  def self.output(data)
    puts "\n=== SEED OUTPUT ==="
    puts data.to_json
    puts "==================="
  end

  # Abort unless CCA site is seeded
  def self.require_site!
    site = BenefitSponsors::Site.all.first
    if site.nil?
      abort "ERROR: No BenefitSponsors::Site found.\n" \
            "Run: bundle exec rails runner db/seedfiles/cca/cca_seed.rb"
    end
    site
  end

  # Find or create a User with a linked Person and optional employer_staff_role.
  # Returns the User.
  def self.find_or_create_user(email:, password:, first_name: "QA", last_name: "User",
                                dob: Date.new(1975, 6, 15), employer_profile: nil)
    user = User.where(email: email).first
    unless user
      person = Person.new(
        first_name: first_name,
        last_name: last_name,
        gender: "male",
        dob: dob
      )
      person.save!(validate: false)

      user = User.new(
        email: email,
        oim_id: email,
        password: password,
        password_confirmation: password,
        approved: true
      )
      user.person = person
      user.save!(validate: false)
      puts "Created user: #{email}"
    end

    if employer_profile
      person = user.person || Person.where(user_id: user.id).first
      unless person&.employer_staff_roles&.where(
        benefit_sponsor_employer_profile_id: employer_profile.id
      ).exists?
        person.employer_staff_roles.create!(
          benefit_sponsor_employer_profile_id: employer_profile.id,
          aasm_state: "is_active"
        )
        puts "Added employer_staff_role to #{email} for profile #{employer_profile.id}"
      end
    end

    user
  end

  # Ensure the employer profile has an approved attestation.
  # Bypasses the submit → approve flow since we have no admin UI in seeds.
  def self.approve_attestation!(profile)
    attestation = profile.employer_attestation

    if attestation.nil?
      attestation = EmployerAttestation.new(aasm_state: "approved")
      profile.employer_attestation = attestation
      profile.save!(validate: false)
      puts "Created and approved attestation for profile #{profile.id}"
    elsif !attestation.approved?
      attestation.update_attribute(:aasm_state, "approved")
      puts "Set attestation to approved for profile #{profile.id}"
    else
      puts "Attestation already approved for profile #{profile.id}"
    end

    attestation
  end

  # Assign a benefit package to all census employees on the profile who don't already
  # have an assignment for this package.
  def self.assign_benefit_package!(profile, benefit_package)
    assigned = 0
    skipped = 0

    CensusEmployee.where(benefit_sponsors_employer_profile_id: profile.id).each do |ce|
      if ce.benefit_group_assignments.any? { |bga| bga.benefit_package_id == benefit_package.id }
        skipped += 1
        next
      end

      ce.benefit_group_assignments.build(
        benefit_package_id: benefit_package.id,
        start_on: [benefit_package.start_on, ce.hired_on].compact.max,
        is_active: true
      )
      ce.save!(validate: false)
      assigned += 1
    end

    puts "BenefitGroupAssignments: #{assigned} assigned, #{skipped} already set"
  end

  # Backdate census_employee.created_at to hired_on so new_hire_enrollment_period
  # starts immediately (avoids "not in eligible enrollment period" block).
  def self.backdate_census_employee!(ce)
    target = ce.hired_on.to_time
    ce.set(created_at: target)
    puts "Backdated created_at for #{ce.full_name} to #{target.to_date}"
  end

  # Find the first available HealthProduct for a given effective date and optionally
  # filter by carrier name substring. Returns the product or nil.
  def self.find_health_product(effective_date: Date.today, carrier_name: nil)
    products = BenefitMarkets::Products::HealthProducts::HealthProduct
                 .where(:"application_period.min".lte => effective_date,
                        :"application_period.max".gte => effective_date)

    if carrier_name
      products = products.select do |p|
        p.issuer_profile&.legal_name.to_s.downcase.include?(carrier_name.downcase)
      end
      products.first
    else
      products.first
    end
  end
end
