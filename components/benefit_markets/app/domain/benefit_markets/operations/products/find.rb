# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module BenefitMarkets
  module Operations
    module Products
      class Find
        include Dry::Monads[:do, :result]

        # Class instance variables
        @products_for_date = {}
        @serialized_product_hash = {}

        class << self
          attr_accessor :products_for_date, :serialized_product_hash
        end

        # @param [ Date ] effective_date Effective date of the benefit application in rfc3339 date format
        # @param [ Array<BenefitMarkets::Entities::ServiceArea> ] service_areas Service Areas
        # @param [ BenefitMarkets::Products::ProductPackage ] product_package Product Package
        # @return [ Array<BenefitMarkets::Entities::Product> ] products Products
        def call(effective_date:, service_areas:, product_package:)
          effective_date     = yield validate_effective_date(effective_date)
          products_params    = yield scope_products(effective_date, service_areas, product_package)
          products           = yield create_products(products_params)
          Success(products)
        end

        private

        # date type check
        def validate_effective_date(effective_date)
          Success(effective_date)
        end

        def create_products(products_params)
          products = products_params.collect do |params|
            ::BenefitMarkets::Operations::Products::Create.new.call(product_params: params).value!
          end

          Success(products)
        end

        def scope_products(effective_date, service_areas, product_package)
          products = products_for_kind_and_date(product_package, effective_date)

          filtered_products = products
                              .by_product_package_kinds(product_package)
                              .by_service_areas(service_areas.map(&:_id))
                              .effective_with_premiums_on(effective_date)

          product_params = filtered_products.collect do |product|
            serialized_product_for(product)
          end

          Success(product_params)
        end

        def products_for_kind_and_date(product_package, effective_date)
          calendar_year = effective_date.year
          self.class.products_for_date[calendar_year] ||= {}
          self.class.products_for_date[calendar_year][product_package.benefit_kind] ||= {}

          # Return cached products if they already exist
          cached_products = self.class.products_for_date[calendar_year][product_package.benefit_kind][product_package.product_kind]
          return cached_products if cached_products

          # Fetch and cache products
          products = ::BenefitMarkets::Products::Product.by_application_period(product_package.application_period)
          cached_products = products.where(
            :benefit_market_kind => product_package.benefit_kind,
            :kind => product_package.product_kind
          )

          self.class.products_for_date[calendar_year][product_package.benefit_kind][product_package.product_kind] = cached_products
          cached_products
        end

        def serialized_product_for(product)
          # Return cached serialized product if available
          cached_product = self.class.serialized_product_hash[product._id]
          return cached_product if cached_product

          # Serialize the product and cache it
          serialized_product = product.create_copy_for_embedding.serializable_hash.deep_symbolize_keys
          self.class.serialized_product_hash[product._id] = serialized_product
          serialized_product
        end

        def self.reset_data
          @products_for_date = {}
          @serialized_product_hash = {}
        end
      end
    end
  end
end
