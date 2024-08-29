# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module BenefitMarkets
  module Operations
    module Pvp
      class FindOrCreate
        send(:include, Dry::Monads[:result, :do])

        # @param [ Hash ] params product_id and rating_area_id
        # @return [ BenefitMarkets::Products::PremiumValueProduct ]
        def call(product_id:, rating_area_id:)
          _values = yield validate(product_id: product_id, rating_area_id: rating_area_id)
          @product = yield find_product(product_id)
          @rating_area = yield find_rating_area(rating_area_id)
          pvp = yield find_or_create

          Success(pvp)
        end

        private

        def validate(params)
          errors = []
          errors << "product_id is missing" unless params[:product_id].present?
          errors << "rating_area_id is missing" unless params[:rating_area_id].present?

          errors.empty? ? Success(params) : Failure(errors)
        end

        def find_product(product_id)
          product = ::BenefitMarkets::Products::Product.find(product_id)
          Success(product)
        rescue Mongoid::Errors::DocumentNotFound
          Failure("Unable to find Product with ID #{product_id}.")
        end

        def find_rating_area(rating_area_id)
          rating_area = ::BenefitMarkets::Locations::RatingArea.find(rating_area_id)
          Success(rating_area)
        rescue Mongoid::Errors::DocumentNotFound
          Failure("Unable to find RatingArea with ID #{rating_area_id}.")
        end

        def persist(pvp)
          pvp.hios_id = @product.hios_id
          pvp.active_year = @product.active_year
          pvp.save!
          Success(pvp)
        rescue StandardError => e
          Failure("Failed to create Premium Value Product for product_id: #{@product.id} and rating_area_id: #{@rating_area.id} due to #{e.inspect}")
        end

        def find_or_create
          pvp = ::BenefitMarkets::Products::PremiumValueProduct.find_or_initialize_by(
            product_id: @product.id,
            rating_area_id: @rating_area.id
          )

          if pvp.persisted?
            Success(pvp)
          else
            persist(pvp)
          end
        end
      end
    end
  end
end