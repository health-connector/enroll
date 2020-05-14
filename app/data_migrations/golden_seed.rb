require File.join(Rails.root, 'lib/mongoid_migration_task')

class GoldenSeed < MongoidMigrationTask
  # Default organization legal names are the employers created in the database dump
  DEFAULT_ORGANIZATION_LEGAL_NAMES = ["Broadcasting llc", "Electric Motors Corp", "MRNA Pharma", "Mobile manf crop", "cuomo family Inc"].freeze

  def get_default_organizations
    if @organization_collection
      @organization_collection
    else
      organization_record_ids = []
      DEFAULT_ORGANIZATION_LEGAL_NAMES.each do |legal_name|
        organization = BenefitSponsors::Organizations::Organization.where(legal_name: legal_name).first
        if organization.present?
          organization_record_ids << organization.id.to_s
        end
      end
      @organization_collection = BenefitSponsors::Organizations::Organization.where(:"_id".in => organization_record_ids)
    end
  end

  def get_benefit_sponsorships_of_organizations
    if @benefit_sponsorships.present?
      @benefit_sponsorships
    else
      @benefit_sponsorships = []
      get_default_organizations.each do |employer|
        if employer.active_benefit_sponsorship
          @benefit_sponsorships << employer.active_benefit_sponsorship
        end
      end
      @benefit_sponsorships
    end
  end

  def get_benefit_applications_of_sponsorships
    if @benefit_applications.present?
      @benefit_applications
    else
      @benefit_applications = []
      get_benefit_sponsorships_of_organizations.each do |benefit_sponsorship|
        if benefit_sponsorship.benefit_applications
          @benefit_applications << benefit_sponsorship.benefit_applications
        end
      end
      @benefit_applications
    end
  end

  def update_dates_of_benefit_applications
    get_benefit_applications_of_sponsorships.each do |benefit_application|
      puts("Benefit application is a " + benefit_application.class.to_s)
      benefit_application.update_attributes!(effective_period: @coverage_start_on..@coverage_end_on)
      benefit_application.reload
      open_enrollment_period = SponsoredBenefits::BenefitApplications::BenefitApplication.open_enrollment_period_by_effective_date(
        benefit_application.effective_period.min
      )
      benefit_application.update_attributes!(open_enrollment_period: open_enrollment_period)
    end
  end

  def recalc_prices_of_benefit_applications
    get_benefit_applications_of_sponsorships.each { |benefit_application| benefit_application.recalc_pricing_determinations }
  end

  def migrate
    coverage_start_on = ENV['coverage_start_on'].to_s
    coverage_end_on = ENV['coverage_end_on'].to_s
    if [coverage_start_on, coverage_end_on].any? { |input| input.blank? }
      raise("Please provide coverage start on and coverage end on (effective period) dates.") unless Rails.env.test?
      return
    else
      @coverage_start_on = ENV['coverage_start_on'].to_date
      @coverage_end_on = ENV['coverage_end_on'].to_date
    end
    puts('Executing migration') unless Rails.env.test?
    get_default_organizations
    get_benefit_sponsorships_of_organizations
    get_benefit_applications_of_sponsorships
    update_dates_of_benefit_applications
    recalc_prices_of_benefit_applications
  end
end
