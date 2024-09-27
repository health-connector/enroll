# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module BenefitMarkets
  module Operations
    module Pvp
      # This operation marks a Product as PVP (Premium Value Product) eligible
      # within a specific Rating Area based on the provided parameters.
      #
      # @example
      #   BenefitMarkets::Operations::Pvp::MarkPvpEligibleInRatingArea.new.call(params)

      class MarkPvpEligibleInRatingArea
        send(:include, Dry::Monads[:result, :do])
        # Executes the operation
        #
        # @param [Hash] params The parameters needed for the operation
        # @option params [String] :hios_id The HIOS ID of the product
        # @option params [Integer] :active_year The active year of the product
        # @option params [String] :rating_area_code The code representing the Rating Area
        # @option params [String] :evidence_value The PVP eligibility status
        # @option params [String] :updated_by The email address of the user making the update
        #
        # @return [Dry::Monads::Result::Success, Dry::Monads::Result::Failure] Result of the operation
        def call(params)
          values = yield validate(params)
          product = yield get_product(values)
          rating_area = yield get_rating_area(values)
          pvp = yield find_or_create_pvp(product, rating_area)
          pvp_eligibility = yield create_or_update_pvp_eligibilities(pvp, values)

          Success(pvp_eligibility)
        end

        private

        def validate(params)
          errors = []
          errors << "HiosId is missing" unless params[:hios_id].present?
          errors << "ActiveYear is missing" unless params[:active_year].present?
          errors << "RatingAreaCode is missing" unless params[:rating_area_code].present?
          errors << "PvpEligibility is missing" unless params[:evidence_value].present?
          @user = User.where(email: params[:updated_by]).first
          errors << "User Not found with email: #{params[:updated_by]}" unless @user.present?

          errors.empty? ? Success(params) : Failure(errors)
        end

        def get_product(values)
          products = ::BenefitMarkets::Products::Product.by_year(values[:active_year]).where(
            hios_id: values[:hios_id]
          )

          if products.count == 1
            Success(products.first)
          else
            Failure("No or more than 1 products found with hios_id: #{values[:hios_id]} and year #{values[:active_year]}")
          end
        end

        def get_rating_area(values)
          exchange_provided_code = "R-MA#{values[:rating_area_code].to_s.rjust(3, '0')}"
          rating_areas = ::BenefitMarkets::Locations::RatingArea.where(
            active_year: values[:active_year],
            exchange_provided_code: exchange_provided_code
          )

          if rating_areas.count == 1
            Success(rating_areas.first)
          else
            Failure("No or more than 1 rating_area found with rating_area_code: #{values[:rating_area_code]} and year #{values[:active_year]}")
          end
        end

        def find_or_create_pvp(product, rating_area)
          ::BenefitMarkets::Operations::Pvp::FindOrCreate.new.call(
            product_id: product.id,
            rating_area_id: rating_area.id
          )
        end

        def create_or_update_pvp_eligibilities(pvp, values)
          effective_date = values[:effective_date] || TimeKeeper.date_of_record
          current_eligibility = pvp.latest_active_pvp_eligibility_on(effective_date)
          return Success(current_eligibility) if current_eligibility.present?.to_s == values[:evidence_value].to_s

          ::BenefitMarkets::Operations::Pvp::CreatePvpEligibility.new.call(
            subject: pvp.to_global_id,
            evidence_key: :shop_pvp_evidence,
            evidence_value: values[:evidence_value].to_s,
            effective_date: effective_date,
            current_user: @user.to_global_id
          )
        end
      end
    end
  end
end
