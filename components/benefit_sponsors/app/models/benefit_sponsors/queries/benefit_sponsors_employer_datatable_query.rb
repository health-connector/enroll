module BenefitSponsors
  module Queries
    class BenefitSponsorsEmployerDatatableQuery
    
    # Not sure if we need this
    attr_reader :search_string, :custom_attributes
    
    # TODO: No clue what to do here
    def initialize(benefit_sponsorships, custom_attributes)
      @benefit_sponsorships = benefit_sponsorships
      @custom_attributes = custom_attributes
    end

    def execute
      # return coverage_report_adapter([]) if application.nil?
      @collection = []

      #s_benefits = application.benefit_packages.map(&:sponsored_benefits).flatten
      #criteria = s_benefits.map { |s_benefit| [s_benefit, query(s_benefit)] }.reject { |pair| pair.last.nil? }
      #coverage_report_adapter(criteria)
    end

    # def query(s_benefit)
    #  query = ::BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentsQuery.new(application, s_benefit).call(::Family, billing_report_date)
    #  # return nil if query.count > 100 # What is this?
    #  query
    # end

    def benefit_sponsorships_adapter(criteria)
      BenefitSponsors::LegacyCoverageReportAdapter.new(criteria)
    end
  end
end
