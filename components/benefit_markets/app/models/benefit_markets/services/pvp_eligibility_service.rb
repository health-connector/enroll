# frozen_string_literal: true

module BenefitMarkets
  module Services
    class PvpEligibilityService
      attr_reader :product, :current_user

      def initialize(product, current_user, args = {})
        @product = product
        @current_user = current_user
        @args = args
      end

      def create_or_update_pvp_eligibilities
        eligibility_result = Hash.new { |h, k| h[k] = [] }

        @args[:rating_areas].each do |rating_area_id, evidence_value|
          if (pvp = find_or_create_pvp(rating_area_id))
            current_eligibility = pvp.latest_active_pvp_eligibility_on(TimeKeeper.date_of_record)
            next if current_eligibility.present?.to_s == evidence_value.to_s

            effective_date = get_effective_date
            result = store_pvp_eligibility(pvp, evidence_value, effective_date)
            eligibility_result[result.success? ? "Success" : "Failure"] << rating_area_id
          else
            eligibility_result["Failure"] << rating_area_id
          end
        end

        eligibility_result
      end

      def find_or_create_pvp(rating_area_id)
        ::BenefitMarkets::Operations::Pvp::FindOrCreate.new.call(
          product_id: @product.id,
          rating_area_id: rating_area_id
        ).success
      end

      def get_effective_date
        return @args[:effective_date] if @args[:effective_date].present?

        @product.application_period.min.to_date
      end

      def store_pvp_eligibility(pvp, evidence_value, effective_date)
        ::BenefitMarkets::Operations::Pvp::CreatePvpEligibility.new.call(
          subject: pvp.to_global_id,
          evidence_key: :shop_pvp_evidence,
          evidence_value: evidence_value.to_s,
          effective_date: effective_date,
          current_user: current_user.to_global_id
        )
      end
    end
  end
end