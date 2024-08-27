# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BenefitMarkets::Operations::Pvp::FindOrCreate, type: :operation, dbclean: :after_each do
  subject { described_class.new }

  let!(:site)            { FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :with_benefit_market_catalog_and_product_packages, :as_hbx_profile, Settings.site.key) }
  let(:effective_date)   { TimeKeeper.date_of_record.next_month.beginning_of_month }
  let(:catalog)          { site.benefit_markets[0].benefit_market_catalogs[0] }
  let(:product)          { catalog.product_packages[0].products.first }
  let(:rating_area)      { product.premium_tables.first.rating_area }

  let(:product_id)       { product.id }
  let(:rating_area_id)   { rating_area.id }

  describe '#call' do
    context 'when successful' do
      it 'returns Success with the PVP' do
        pvp = BenefitMarkets::Products::PremiumValueProduct.create(product_id: product_id, rating_area_id: rating_area_id)
        result = subject.call(product_id: product_id, rating_area_id: rating_area_id)
        expect(result).to be_success
        expect(result.success).to eq(pvp)
      end
    end

    context 'when validation fails' do
      it 'returns Failure with errors if product_id is missing' do
        result = subject.call(product_id: nil, rating_area_id: rating_area_id)
        expect(result).to be_failure
        expect(result.failure).to include('product_id is missing')
      end

      it 'returns Failure with errors if rating_area_id is missing' do
        result = subject.call(product_id: product_id, rating_area_id: nil)
        expect(result).to be_failure
        expect(result.failure).to include('rating_area_id is missing')
      end
    end

    context 'when the product is not found' do
      before do
        allow(BenefitMarkets::Products::Product).to receive(:find).with(product_id)
                                                                  .and_raise(Mongoid::Errors::DocumentNotFound.new(product.class, nil, nil))
      end

      it 'returns Failure with a product not found error' do
        result = subject.call(product_id: product_id, rating_area_id: rating_area_id)
        expect(result).to be_failure
        expect(result.failure).to eq("Unable to find Product with ID #{product_id}.")
      end
    end

    context 'when the rating area is not found' do
      before do
        allow(BenefitMarkets::Locations::RatingArea).to receive(:find).with(rating_area_id)
                                                                      .and_raise(Mongoid::Errors::DocumentNotFound.new(rating_area.class, nil, nil))
      end

      it 'returns Failure with a rating area not found error' do
        result = subject.call(product_id: product_id, rating_area_id: rating_area_id)
        expect(result).to be_failure
        expect(result.failure).to eq("Unable to find RatingArea with ID #{rating_area_id}.")
      end
    end

    context 'when persisting the PVP succefull' do
      it 'returns Failure with a persistence error' do
        result = subject.call(product_id: product_id, rating_area_id: rating_area_id)
        expect(result).to be_success
        expect(result.success).is_a?(BenefitMarkets::Products::PremiumValueProduct)
      end
    end

    context 'when persisting the PVP fails' do
      before do
        allow_any_instance_of(BenefitMarkets::Products::PremiumValueProduct).to receive(:save!).and_raise(StandardError, 'save error')
      end

      it 'returns Failure with a persistence error' do
        result = subject.call(product_id: product_id, rating_area_id: rating_area_id)
        expect(result).to be_failure
        expect(result.failure).to eq(
          "Failed to create Premium Value Product for product_id: #{product_id} and rating_area_id: #{rating_area_id} due to #<StandardError: save error>"
        )
      end
    end
  end
end
