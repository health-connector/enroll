require File.join(Rails.root, 'lib/mongoid_migration_task')

class GoldenSeed < MongoidMigrationTask
  # Default organization legal names are the employers created in the database dump
  DEFAULT_ORGANIZATION_LEGAL_NAMES = ["Broadcasting llc", "Electric Motors Corp", "MRNA Pharma", "Mobile manf crop", "cuomo family Inc"].freeze

  # TODO: Placeholder as note
  COVERAGE_QUARTER_PERIODS = {
    quarter_1: "01/01..3/31",
    quarter_2: "04/01..06/30",
    quarter_3: "07/01..09/30",
    quarter_4: "10/01..12/31"
  }

  def get_default_organizations
    if @organization_collection
      @organization_collection
    else
      organization_record_ids = []
      DEFAULT_ORGANIZATION_LEGAL_NAMES.each do |legal_name|
        organization = BenefitSponsors::Organizations::Organization.all.where(legal_name: legal_name).first.id.to_s
        organization_record_ids << organization
      end
      @organization_collection = BenefitSponsors::Organizations::Organization.all.where(:"_id".in => organization_record_ids)
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
        # TODO: Future use case
        # else
        #  create_benefit_sponsorship(employer)
        #  employer.reload
        #  @benefit_sponsorships << employer.active_benefit_sponsorship
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
  
  # TODO: Enhance this to use benefit sponsorship id list rather than
  # hard coded employer names
  # def get_organizations_by_benefit_sponsorship_ids(benefit_sponsorship_id_list)
  #   @organization_collection = []
  # end

  def update_dates_of_benefit_applications
    get_benefit_applications_of_sponsorships.each do |benefit_application|
      benefit_application.update_attributes!(
        start_on: @coverage_start_on,
        end_on: @coverage_end_on,
        open_enrollment_start_on: @open_enrollment_start_on,
        open_enrollment_end_on: @open_enrollment_end_on
      )
    end
  end

  def recalc_prices_of_benefit_applications
    get_benefit_applications_of_sponsorships.each do |benefit_application|
      benefit_application.recalc_pricing_determinations
    end
  end

  def migrate
    benefit_sponsorship_id_list = ENV['benefit_sponsorship_ids'].to_s
    coverage_start_on = ENV['coverage_start_on'].to_s
    coverage_end_on = ENV['coverage_end_on'].to_s
    open_enrollment_start_on = ENV['open_enrollment_start_on'].to_s
    open_enrollment_end_on = ENV['open_enrollment_end_on'].to_s
    if [coverage_start_on, coverage_end_on, open_enrollment_start_on, open_enrollment_end_on].any? { |input| input.blank? }
      raise("Please provide coverage start on, coverage end on, open enrollment start on, and open enrollment end on dates.") unless Rails.env.test?
      return
    else
      @coverage_start_on = ENV['coverage_start_on'].to_date
      @coverage_end_on = ENV['coverage_end_on'].to_date
      @open_enrollment_start_on = ENV['open_enrollment_start_on'].to_date
      @open_enrollment_end_on = ENV['open_enrollment_end_on'].to_date
    end
    # TODO: Enhance this to take a benefit sponsorship id list in case
    # a different seed withd different organizations is being used
    # if benefit_sponsorship_id_list.blank?
    #  get_default_organizations
    # end
    puts('Executing migration') unless Rails.env.test?
    get_benefit_sponsorships_of_organizations
    get_benefit_applications_of_sponsorships
    update_dates_of_benefit_applications
    recalc_prices_of_benefit_applications
  end
end
