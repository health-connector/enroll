module BenefitSponsors
  module Services
    class EmployerDataTableService

      attr_accessor :filter

      def initialize(params={})
        @filter = params[:filter]
      end

      def get_table_data
        case @filter
        when nil, 'all'
          benefit_sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.all
        when 'applicants'
          benefit_sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.benefit_sponsorship_applicant
        when 'enrolling'
          benefit_sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.benefit_application_enrolling
        when 'enrolled'
          benefit_sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.benefit_application_enrolled
        end
        benefit_sponsorships
      end

    end
  end
end
