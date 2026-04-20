# frozen_string_literal: true

# Broker Ready Seed
#
# Creates an active broker linked to a new broker agency org,
# plus a user account for the broker.
#
# ENV vars (optional — defaults provided):
#   QA_BROKER_EMAIL      — broker login email (default: broker_qa@example.com)
#   QA_BROKER_NPN        — unique NPN (default: QA123456)
#   QA_BROKER_FIRST      — first name (default: Bob)
#   QA_BROKER_LAST        — last name (default: Broker)
#   QA_AGENCY_NAME       — broker agency legal name (default: QA Broker Agency, Inc.)
#
# Output JSON:
#   broker_agency_profile_id, broker_role_id, broker_person_id, npn, email

load File.join(__dir__, 'helpers.rb')

BROKER_EMAIL     = ENV.fetch('QA_BROKER_EMAIL', 'broker_qa@example.com')
BROKER_PASSWORD  = 'Password1!'
BROKER_NPN       = ENV.fetch('QA_BROKER_NPN', 'QA123456')
BROKER_FIRST     = ENV.fetch('QA_BROKER_FIRST', 'Bob')
BROKER_LAST      = ENV.fetch('QA_BROKER_LAST', 'Broker')
AGENCY_NAME      = ENV.fetch('QA_AGENCY_NAME', 'QA Broker Agency, Inc.')

QASeed.require_site!

# ── 1. Broker Agency Org ───────────────────────────────────────────────────────
agency_org = BenefitSponsors::Organizations::Organization
  .where('profiles._type' => 'BenefitSponsors::Organizations::BrokerAgencyProfile',
         'legal_name' => AGENCY_NAME)
  .first

unless agency_org
  site = BenefitSponsors::Site.all.first

  agency_profile = BenefitSponsors::Organizations::BrokerAgencyProfile.new(
    market_kind: 'both',
    accept_new_clients: true,
    working_hours: false,
    aasm_state: 'is_approved'
  )
  agency_profile.office_locations.build(
    is_primary: true,
    address: Address.new(
      kind: 'primary',
      address_1: '100 Broker St',
      city: 'Boston',
      state: 'MA',
      zip: '02101'
    ),
    phone: Phone.new(kind: 'work', area_code: '617', number: '555-0100')
  )

  agency_org = BenefitSponsors::Organizations::ExemptOrganization.new(
    legal_name: AGENCY_NAME,
    fein: '521234567',
    site: site,
    profiles: [agency_profile]
  )
  agency_org.save!(validate: false)
  puts "Created broker agency org: #{AGENCY_NAME}"
else
  puts "Found existing broker agency org: #{AGENCY_NAME}"
end

agency_profile = agency_org.profiles.detect { |p|
  p._type == 'BenefitSponsors::Organizations::BrokerAgencyProfile'
}

# ── 2. Broker Person + BrokerRole ─────────────────────────────────────────────
broker_person = Person.where('broker_role.npn' => BROKER_NPN).first

unless broker_person
  broker_person = Person.new(
    first_name: BROKER_FIRST,
    last_name: BROKER_LAST,
    gender: 'male',
    dob: Date.new(1980, 3, 15)
  )
  broker_person.emails.build(kind: 'work', address: BROKER_EMAIL)
  broker_person.save!(validate: false)
  puts "Created broker person: #{BROKER_FIRST} #{BROKER_LAST}"
end

# Ensure email is present (required by broker agency view)
unless broker_person.emails.any?
  broker_person.emails.build(kind: 'work', address: BROKER_EMAIL)
  broker_person.save!(validate: false)
  puts "Added email to broker person"
end

broker_role = broker_person.broker_role
unless broker_role
  broker_person.build_broker_role(
    npn: BROKER_NPN,
    broker_agency_profile_id: agency_profile.id,
    benefit_sponsors_broker_agency_profile_id: agency_profile.id,
    provider_kind: 'broker',
    market_kind: 'both',
    license: true,
    training: true,
    aasm_state: 'applicant'
  )
  # Bypass callbacks to set active directly
  broker_person.save!(validate: false)
  broker_role = broker_person.reload.broker_role
  # Force active state
  broker_role.update_attribute(:aasm_state, 'active')
  puts "Created and activated broker role for #{BROKER_FIRST} #{BROKER_LAST}"
else
  broker_role.update_attribute(:aasm_state, 'active') unless broker_role.aasm_state == 'active'
  puts "Found existing broker role (npn: #{BROKER_NPN}), ensured active"
end

broker_person.reload
broker_role = broker_person.broker_role

# ── 3. Link broker as primary_broker of the agency ───────────────────────────
unless agency_profile.primary_broker_role_id == broker_role.id
  agency_profile.update_attribute(:primary_broker_role_id, broker_role.id)
  puts "Set primary_broker_role_id on agency profile"
end

# ── 4. Broker User account ───────────────────────────────────────────────────
user = User.where(email: BROKER_EMAIL).first
unless user
  user = User.new(
    email: BROKER_EMAIL,
    oim_id: BROKER_EMAIL,
    password: BROKER_PASSWORD,
    password_confirmation: BROKER_PASSWORD,
    approved: true,
    roles: ['broker']
  )
  user.person = broker_person
  user.save!(validate: false)
  puts "Created broker user: #{BROKER_EMAIL}"
else
  puts "Found existing broker user: #{BROKER_EMAIL}"
end

# ── 5. Output ─────────────────────────────────────────────────────────────────
QASeed.output(
  broker_agency_profile_id: agency_profile.id.to_s,
  broker_role_id: broker_role.id.to_s,
  broker_person_id: broker_person.id.to_s,
  npn: BROKER_NPN,
  email: BROKER_EMAIL,
  password: BROKER_PASSWORD,
  agency_name: AGENCY_NAME
)
