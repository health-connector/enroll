# frozen_string_literal: true

require 'rails_helper'

module BenefitMarkets
  RSpec.describe Products::PremiumValueProduct, type: :model, dbclean: :after_each do
    describe 'fields' do
      it { is_expected.to have_field(:hios_id).of_type(String) }
      it { is_expected.to have_field(:active_year).of_type(Integer) }
    end

    describe 'associations' do
      it { is_expected.to belong_to(:product) }
      it { is_expected.to have_field(:product_id).of_type(Object) }
      it { is_expected.to belong_to(:rating_area) }
      it { is_expected.to have_field(:rating_area_id).of_type(Object) }
    end

    describe '.by_rating_area_code_and_year' do
      let!(:site)            { FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :with_benefit_market_catalog_and_product_packages, :as_hbx_profile, Settings.site.key) }
      let(:effective_date)   { TimeKeeper.date_of_record.beginning_of_year }
      let(:catalog)          { site.benefit_markets[0].benefit_market_catalogs[0] }
      let(:product)          { catalog.product_packages[0].products.first }
      let!(:rating_area_2024) { FactoryBot.create(:benefit_markets_locations_rating_area, exchange_provided_code: 'R-MA001', active_year: 2024) }
      let!(:rating_area_2023) { FactoryBot.create(:benefit_markets_locations_rating_area, exchange_provided_code: 'R-MA001', active_year: 2023) }
      let!(:rating_area_2_2024) { FactoryBot.create(:benefit_markets_locations_rating_area, exchange_provided_code: 'R-MA002', active_year: 2024) }

      let!(:pvp_1) { FactoryBot.create(:benefit_markets_products_premium_value_product, product: product, rating_area: rating_area_2024) }
      let!(:pvp_2) { FactoryBot.create(:benefit_markets_products_premium_value_product, product: product, rating_area: rating_area_2023) }
      let!(:pvp_3) { FactoryBot.create(:benefit_markets_products_premium_value_product, product: product, rating_area: rating_area_2_2024) }

      it 'returns records for the correct rating area code and year' do
        results = described_class.by_rating_area_code_and_year('R-MA001', 2024)

        expect(results).to include(pvp_1)
        expect(results).not_to include(pvp_2)
        expect(results).not_to include(pvp_3)
      end

      it 'returns no records if no rating areas match the code and year' do
        results = described_class.by_rating_area_code_and_year('R-MA001', 2025)

        expect(results).to be_empty
      end
    end
  end
end
