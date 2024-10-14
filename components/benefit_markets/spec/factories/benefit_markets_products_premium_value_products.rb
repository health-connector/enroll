# frozen_string_literal: true

FactoryBot.define do
  factory :benefit_markets_products_premium_value_product, class: 'BenefitMarkets::Products::PremiumValueProduct' do

    active_year { TimeKeeper.date_of_record.year }
    sequence(:hios_id, (10..99).cycle)  { |n| "41842DC04000#{n}-01" }

    product { create(:benefit_markets_products_health_products_health_product)  }
    rating_area { create(:benefit_markets_locations_rating_area) }
  end
end
