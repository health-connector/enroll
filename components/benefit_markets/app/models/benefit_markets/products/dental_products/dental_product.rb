# frozen_string_literal: true

module BenefitMarkets
  module Products
    module DentalProducts
      class DentalProduct < BenefitMarkets::Products::Product

        PRODUCT_PACKAGE_KINDS = [:single_product, :multi_product].freeze
        METAL_LEVEL_KINDS     = [:dental].freeze

        field :hios_id,                     type: String
        field :hios_base_id,                type: String
        field :csr_variant_id,              type: String
        field :dental_level,                type: String
        field :dental_plan_kind,            type: Symbol

        field :hsa_eligibility,             type: Boolean,  default: false
        field :is_standard_plan,            type: Boolean,  default: false

        field :metal_level_kind,            type: Symbol
        field :ehb,                         type: Float,    default: 0.0

        belongs_to  :renewal_product,
                    inverse_of: nil,
                    class_name: "BenefitMarkets::Products::DentalProducts::DentalProduct",
                    optional: true

        validates :metal_level_kind,
                  presence: true,
                  inclusion: {in: METAL_LEVEL_KINDS, message: "%<value>s is not a valid metal level kind"}

        alias is_standard_plan? is_standard_plan

        def metal_level
          dental_level.to_s
        end

        def product_type
          dental_plan_kind.to_s
        end

      end
    end
  end
end
