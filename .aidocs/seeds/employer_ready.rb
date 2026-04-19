# frozen_string_literal: true

# QA Seed: Employer Ready
#
# Creates a new employer organization with ALL prerequisites satisfied for plan year creation:
#   - AcaShopCcaEmployerProfile with zip 01247 (Berkshire, MA) — valid rating area in dev
#   - Approved EmployerAttestation (bypasses submit → approve flow)
#   - BenefitSponsorship via factory
#   - Employer staff user with employer_staff_role
#
# Usage:
#   source ~/.rvm/scripts/rvm && rvm use 3.4.7@ma
#   bundle exec rails runner .aidocs/seeds/employer_ready.rb
#
# Output JSON:
#   {
#     "employer_email": "employer_qa_<ts>@example.com",
#     "employer_password": "aA1!aA1!aA1!",
#     "profile_id": "<bson_id>",
#     "sponsorship_id": "<bson_id>",
#     "org_legal_name": "QA Employer <ts>"
#   }
#
# Prerequisites:
#   - CCA site must be seeded: bundle exec rails runner db/seedfiles/cca/cca_seed.rb

require 'factory_bot_rails'

load File.join(__dir__, 'helpers.rb')

begin
  FactoryBot.find_definitions unless FactoryBot.factories.count > 0
rescue StandardError
  nil
end

puts "=== QA Seed: Employer Ready ==="

site = QASeed.require_site!

ts = Time.now.to_i
legal_name = ENV.fetch("QA_ORG_NAME", "QA Employer #{ts}")
email      = ENV.fetch("QA_EMPLOYER_EMAIL", "employer_qa_#{ts}@example.com")
password   = "aA1!aA1!aA1!"

# ── 1. Create GeneralOrganization with AcaShopCcaEmployerProfile ──────────────

# Use zip 01247 — Berkshire County, MA — confirmed valid rating area in dev seed
org = BenefitSponsors::Organizations::GeneralOrganization.where(legal_name: legal_name).first

unless org
  fein = rand(100_000_000..999_999_999).to_s

  # Build profile with Berkshire zip for valid rating area
  profile = BenefitSponsors::Organizations::AcaShopCcaEmployerProfile.new(
    sic_code: "0111"
  )
  profile.office_locations.build(
    is_primary: true,
    address: BenefitSponsors::Locations::Address.new(
      kind: "primary",
      address_1: "100 Main St",
      city: "Pittsfield",
      state: "MA",
      zip: "01247",
      county: "Berkshire"
    ),
    phone: BenefitSponsors::Locations::Phone.new(kind: "work", area_code: "413", number: "5550100")
  )

  org = BenefitSponsors::Organizations::GeneralOrganization.new(
    site: site,
    legal_name: legal_name,
    dba: legal_name,
    fein: fein,
    entity_kind: :c_corporation
  )
  org.profiles << profile
  org.save!(validate: false)
  puts "Created organization: #{legal_name} (FEIN: #{fein})"
end

profile = org.employer_profile
abort "ERROR: No AcaShopCcaEmployerProfile on org #{legal_name}" unless profile

# ── 2. Ensure BenefitSponsorship exists ────────────────────────────────────────

sponsorship = profile.benefit_sponsorships.first
unless sponsorship
  sponsorship = profile.benefit_sponsorships.create!(
    source_kind: :self_serve,
    registered_on: Date.today - 1.year,
    market_kind: :shop,
    benefit_market: site.benefit_markets.first
  )
  puts "Created BenefitSponsorship: #{sponsorship.id}"
end

# ── 3. Approve attestation ─────────────────────────────────────────────────────

QASeed.approve_attestation!(profile)

# ── 4. Create employer staff user ─────────────────────────────────────────────

user = QASeed.find_or_create_user(
  email: email,
  password: password,
  first_name: "Employer",
  last_name: "QA",
  employer_profile: profile
)

# ── Output ─────────────────────────────────────────────────────────────────────

QASeed.output(
  employer_email:   email,
  employer_password: password,
  profile_id:        profile.id.to_s,
  sponsorship_id:    sponsorship.id.to_s,
  org_legal_name:    legal_name,
  org_id:            org.id.to_s
)
