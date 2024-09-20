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
          pvp = find_or_create_pvp(rating_area_id)
          if pvp.present?
            current_eligibility = pvp.latest_active_pvp_eligibility_on(TimeKeeper.date_of_record)
            next if current_eligibility.present?.to_s == evidence_value.to_s

            effective_date = get_effective_date(evidence_value)
            result = store_pvp_eligibility(pvp, evidence_value, effective_date)
            eligibility_result[rating_area_id] = result.success? ? "Success" : "Failure"
          else
            eligibility_result[rating_area_id] = "Failure"
          end
        end

        grouped_eligibilities = eligibility_result.group_by { |_year, value| value }
        grouped_eligibilities.transform_values { |items| items.map(&:first) }
      end

      def find_or_create_pvp(rating_area_id)
        ::BenefitMarkets::Operations::Pvp::FindOrCreate.new.call(
          product_id: @product.id,
          rating_area_id: rating_area_id
        ).success
      end

      def get_effective_date(evidence_value)
        return @args[:effective_date] if @args[:effective_date].present?

        if evidence_value.to_s == "true"
          @product.application_period.min.to_date
        else
          TimeKeeper.date_of_record
        end
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