# frozen_string_literal: true

# QA Seed: Plan Year Published
#
# Creates a BenefitApplication (plan year) for an existing employer, adds a benefit package,
# assigns ALL census employees to the package, then publishes to :enrollment_open.
#
# Handles the known gotchas:
#   - benefit_sponsor_catalog must be fetched for the application period
#   - All census employees need BenefitGroupAssignments before publishing
#   - Uses AASM transitions: draft → approved → enrollment_open
#
# Usage:
#   PROFILE_ID=<id> SPONSORSHIP_ID=<id> bundle exec rails runner .aidocs/seeds/plan_year_published.rb
#
#   Or set ENV vars:
#     QA_START_DATE   — plan year start, default: next month's 1st
#     QA_PACKAGE_NAME — benefit package title, default: "Standard Health Package"
#
# Output JSON:
#   {
#     "application_id": "<id>",
#     "package_id": "<id>",
#     "start_date": "YYYY-MM-DD",
#     "end_date": "YYYY-MM-DD",
#     "open_enrollment_start": "YYYY-MM-DD",
#     "open_enrollment_end": "YYYY-MM-DD"
#   }

load File.join(__dir__, 'helpers.rb')

puts "=== QA Seed: Plan Year Published ==="

# ── Config ─────────────────────────────────────────────────────────────────────

profile_id     = ENV.fetch("PROFILE_ID") { abort "ERROR: Set PROFILE_ID env var" }
sponsorship_id = ENV.fetch("SPONSORSHIP_ID") { abort "ERROR: Set SPONSORSHIP_ID env var" }

start_date    = ENV["QA_START_DATE"] ? Date.parse(ENV["QA_START_DATE"]) : (Date.today.next_month.beginning_of_month)
end_date      = start_date + 1.year - 1.day
oe_start      = start_date - 30.days
oe_end        = start_date - 6.days
package_name  = ENV.fetch("QA_PACKAGE_NAME", "Standard Health Package")

# ── Load records ───────────────────────────────────────────────────────────────

profile     = BenefitSponsors::Organizations::AcaShopCcaEmployerProfile.find(profile_id)
sponsorship = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.find(sponsorship_id)

puts "Employer: #{profile.organization.legal_name}"
puts "Plan year: #{start_date} – #{end_date}"
puts "Open enrollment: #{oe_start} – #{oe_end}"

# ── 1. Get or create BenefitSponsorCatalog ────────────────────────────────────

effective_period = start_date..end_date
catalog = sponsorship.benefit_sponsor_catalog_for(effective_period.min)

abort "ERROR: No BenefitSponsorCatalog available for #{start_date}.\n" \
      "Ensure benefit market catalog is seeded for this period." if catalog.nil?

puts "BenefitSponsorCatalog: #{catalog.id}"

# ── 2. Find service and rating areas ──────────────────────────────────────────

service_areas = BenefitMarkets::Locations::ServiceArea.service_areas_for(
  profile.primary_office_location.address,
  during: start_date
)
rating_area = BenefitMarkets::Locations::RatingArea.rating_area_for(
  profile.primary_office_location.address,
  during: start_date
)

if service_areas.blank? || rating_area.nil?
  abort "ERROR: No service/rating area found for profile address (zip: #{profile.primary_office_location.address.zip}).\n" \
        "Change employer zip to 01247 (Berkshire) — confirmed valid in dev."
end

puts "Rating area: #{rating_area.exchange_provided_code}"
puts "Service areas: #{service_areas.count}"

# ── 3. Create BenefitApplication ─────────────────────────────────────────────

existing = sponsorship.benefit_applications
              .where(:"effective_period.min" => start_date)
              .reject { |a| a.canceled? || a.terminated? }
              .first

if existing
  puts "Using existing benefit application: #{existing.id} (#{existing.aasm_state})"
  application = existing
else
  application = BenefitSponsors::BenefitApplications::BenefitApplication.new(
    benefit_sponsorship: sponsorship,
    effective_period: effective_period,
    open_enrollment_period: oe_start..oe_end,
    recorded_service_areas: service_areas,
    recorded_rating_area: rating_area,
    recorded_sic_code: profile.sic_code || "0111",
    fte_count: 5,
    pte_count: 0,
    msp_count: 0,
    benefit_sponsor_catalog: catalog
  )
  catalog.benefit_application = application
  catalog.save!
  application.save!(validate: false)
  puts "Created BenefitApplication: #{application.id}"
end

# ── 4. Create BenefitPackage with HealthSponsoredBenefit ──────────────────────

existing_package = application.benefit_packages.where(title: package_name).first

if existing_package
  puts "Using existing benefit package: #{existing_package.id}"
  package = existing_package
else
  # Find a product_package from the catalog (single_issuer or single_product)
  product_package = catalog.product_packages
                           .by_product_kind(:health)
                           .detect { |pp| [:single_issuer, :single_product].include?(pp.package_kind.to_sym) }

  abort "ERROR: No health product_package in catalog. Seed benefit market catalog first." if product_package.nil?

  # Find a reference product (prefer BCBS if available)
  reference_product = product_package.products
                                     .detect { |p| p.issuer_profile&.legal_name.to_s.downcase.include?("blue cross") } ||
                      product_package.products.first

  abort "ERROR: No health products in product_package." if reference_product.nil?

  puts "Reference product: #{reference_product.title} (#{reference_product.hios_id})"

  # Build SponsorContribution with standard relationship benefits
  contribution = BenefitSponsors::SponsoredBenefits::FixedPercentSponsorContribution.new
  product_package.contribution_model.contribution_units.each do |cu|
    contribution.contribution_levels.build(
      display_name: cu.display_name,
      contribution_unit_id: cu.id,
      is_offered: cu.default_is_offered,
      contribution_factor: 0.5
    )
  end

  sponsored_benefit = BenefitSponsors::SponsoredBenefits::CcaShopHealthSponsoredBenefit.new(
    product_package_kind: product_package.package_kind,
    product_option_choice: product_package.products.map { |p| p.issuer_profile_id }.uniq.first&.to_s,
    reference_product: reference_product,
    sponsor_contribution: contribution
  )

  package = BenefitSponsors::BenefitPackages::BenefitPackage.new(
    title: package_name,
    description: "QA seed benefit package",
    probation_period_kind: :first_of_month,
    is_default: true,
    is_active: true
  )
  package.sponsored_benefits << sponsored_benefit
  application.benefit_packages << package
  application.save!(validate: false)
  puts "Created BenefitPackage: #{package.id}"
end

# ── 5. Assign all census employees to the package ─────────────────────────────

QASeed.assign_benefit_package!(profile, package)

# ── 6. Publish: draft → approved → enrollment_open ───────────────────────────

case application.aasm_state.to_sym
when :draft
  if application.may_approve_application?
    application.approve_application!
    puts "Transitioned to: approved"
  else
    application.update_attribute(:aasm_state, :approved)
    puts "Force-set to: approved"
  end
  application.reload
end

if [:approved].include?(application.aasm_state.to_sym)
  if application.may_begin_open_enrollment?
    application.begin_open_enrollment!
    puts "Transitioned to: enrollment_open"
  else
    application.update_attribute(:aasm_state, :enrollment_open)
    puts "Force-set to: enrollment_open"
  end
end

application.reload
puts "Final state: #{application.aasm_state}"

# ── Output ─────────────────────────────────────────────────────────────────────

QASeed.output(
  application_id:       application.id.to_s,
  package_id:           package.id.to_s,
  aasm_state:           application.aasm_state.to_s,
  start_date:           start_date.to_s,
  end_date:             end_date.to_s,
  open_enrollment_start: oe_start.to_s,
  open_enrollment_end:   oe_end.to_s
)
