# frozen_string_literal: true

module BenefitSponsors
  module Entities
    class BenefitApplication < Dry::Struct
      transform_keys(&:to_sym)

      attribute :expiration_date,             Types::Date.optional
      # attribute :effective_period,            Types::Range
      attribute :open_enrollment_period,      Types::Range
      # attribute :terminated_on,               Types::Date.optional.meta(omittable: true)
      attribute :aasm_state,                  Types::Strict::Symbol
      attribute :fte_count,                   Types::Strict::Integer
      attribute :pte_count,                   Types::Strict::Integer.optional
      attribute :msp_count,                   Types::Strict::Integer.optional
      attribute :recorded_sic_code,           Types::String.optional
      attribute :predecessor_id,              Types::Bson.optional
      attribute :recorded_rating_area_id,     Types::Bson
      attribute :recorded_service_area_ids,   Types::Strict::Array
      attribute :benefit_sponsor_catalog_id,  Types::Bson
      attribute :termination_kind,            Types::String.optional.meta(omittable: true)
      attribute :termination_reason,          Types::String.optional.meta(omittable: true)
      attribute :benefit_application_items,   Types::Array.of(BenefitSponsors::Entities::BenefitApplicationItem)


      def is_termed_or_ineligible?
        [:terminated, :termination_pending, :enrollment_ineligible].include? aasm_state
      end

      def earliest_benefit_application_item
        benefit_application_items.min_by { |item| item.effective_period.min }
      end

      # def latest_benefit_application_item
      #   benefit_application_items.min_by { |item| item.effective_period.min }
      # end

      # def effective_period
      # end

      # def terminated_on
      #   return nil unless (aasm_state == :termination_pending || aasm_state == :terminated)


      # end
    end
  end
end
