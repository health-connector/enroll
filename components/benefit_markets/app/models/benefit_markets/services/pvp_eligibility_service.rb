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
        eligibility_result = {}

        @args[:rating_areas].each do |rating_area_id, evidence_value|
          pvp = get_premium_value_product(rating_area_id)
          effective_date = @args[:effective_date] || TimeKeeper.date_of_record
          current_eligibility = pvp.latest_active_pvp_eligibility_on(effective_date)
          next if current_eligibility.present?.to_s == evidence_value.to_s

          result = store_pvp_eligibility(pvp, evidence_value, effective_date)
          eligibility_result[rating_area_id] = result.success? ? "Success" : "Failure"
        end

        grouped_eligibilities = eligibility_result.group_by { |_year, value| value }
        grouped_eligibilities.transform_values { |items| items.map(&:first) }
      end

      def get_premium_value_product(rating_area_id)
        ::BenefitMarkets::Operations::Pvp::FindOrCreate.new.call(
          product_id: @product.id,
          rating_area_id: rating_area_id
        ).success
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