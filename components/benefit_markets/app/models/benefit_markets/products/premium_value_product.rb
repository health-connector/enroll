# frozen_string_literal: true

module BenefitMarkets
  module Products
    class PremiumValueProduct
      include Mongoid::Document
      include Mongoid::Timestamps

      field :hios_id,     type: String
      field :active_year, type: Integer

      belongs_to :product, class_name: "BenefitMarkets::Products::Product"
      belongs_to :rating_area, class_name: "BenefitMarkets::Locations::RatingArea"

      validates :product_id, :rating_area_id, presence: true

      embeds_many :eligibilities, class_name: '::Eligible::Eligibility', as: :eligible, cascade_callbacks: true

    end
  end
end