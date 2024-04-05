module SponsoredBenefits
  module Organizations
    class AcaShopCcaEmployerProfile < Profile
      include Concerns::AcaRatingAreaConfigConcern

      field :sic_code, type: String
      embeds_one  :employer_attestation, class_name: '::EmployerAttestation'
      embedded_in :plan_design_proposal, class_name: "SponsoredBenefits::Organizations::PlanDesignProposal"

      after_initialize :initialize_benefit_sponsorship

      def primary_office_location
        (organization || plan_design_organization).primary_office_location
      end

      def rating_area
        return nil if use_simple_employer_calculation_model?

        proposal_for = benefit_application.effective_period.min.year if benefit_application
        RatingArea.rating_area_for(primary_office_location.address, proposal_for)
      end

      def service_areas
        return nil if use_simple_employer_calculation_model?

        CarrierServiceArea.service_areas_for(office_location: primary_office_location)
      end

      def service_areas_available_on(date)
        return [] if use_simple_employer_calculation_model?

        CarrierServiceArea.service_areas_available_on(primary_office_location.address, date.year)
      end

      def service_area_ids
        return nil if use_simple_employer_calculation_model?

        service_areas.collect { |service_area| service_area.service_area_id }.uniq
      end

      private

      def initialize_benefit_sponsorship
        benefit_sponsorships.build(benefit_market: :aca_shop_cca, enrollment_frequency: :rolling_month) if benefit_sponsorships.blank?
      end
    end
  end
end
