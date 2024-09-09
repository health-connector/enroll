# frozen_string_literal: true

module BenefitMarkets
  module Products
    class PremiumValueProduct
      include Mongoid::Document
      include Mongoid::Timestamps
      include GlobalID::Identification

      field :hios_id,     type: String
      field :active_year, type: Integer

      belongs_to :product, class_name: "BenefitMarkets::Products::Product"
      belongs_to :rating_area, class_name: "BenefitMarkets::Locations::RatingArea"

      validates :product_id, :rating_area_id, presence: true

      embeds_many :eligibilities, class_name: '::Eligible::Eligibility', as: :eligible, cascade_callbacks: true

      index(
        { "eligibilities.key" => 1 },
        {name: "premium_value_products_eligibilities_key_index"}
      )

      scope :by_rating_area_code_and_year, lambda { |code, year|
        rating_area_ids = BenefitMarkets::Locations::RatingArea.where(
          exchange_provided_code: code,
          active_year: year
        ).pluck(:id)

        where(:rating_area_id.in => rating_area_ids)
      }

      def pvp_eligibilities
        eligibilities.by_key(:cca_shop_pvp_eligibility)
      end

      def active_pvp_eligibilities_on(date = TimeKeeper.date_of_record)
        pvp_eligibilities.select{|eligibility| eligibility.is_eligible_on?(date) }
      end

      def latest_active_pvp_eligibility_on(date = TimeKeeper.date_of_record)
        active_pvp_eligibilities_on(date).max_by(&:created_at)
      end
    end
  end
end