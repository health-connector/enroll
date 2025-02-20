# frozen_string_literal: true

require "rails_helper"

RSpec.describe BenefitMarkets::Operations::Products::Find, dbclean: :after_each do

  let!(:site)                   { create(:benefit_sponsors_site, :with_benefit_market, :with_benefit_market_catalog_and_product_packages, :as_hbx_profile, Settings.site.key) }
  let(:effective_date)          { TimeKeeper.date_of_record.next_month.beginning_of_month }
  let(:product_package)         { site.benefit_markets[0].benefit_market_catalogs[0].product_packages[0] }
  let(:service_areas)           { product_package.products.map(&:service_area) }

  let(:params)                  { {effective_date: effective_date, service_areas: service_areas, product_package: product_package} }

  before do
    allow(TimeKeeper).to receive(:date_of_record).and_return(Date.new(TimeKeeper.date_of_record.year, 10,1))
  end

  after do
    described_class.reset_data
    allow(TimeKeeper).to receive(:date_of_record).and_call_original
  end

  context 'sending required parameters' do
    it 'should find Product' do
      expect(subject.call(**params).success?).to be_truthy
      expect(subject.call(**params).success.first.class.to_s).to match(/BenefitMarkets::Entities::HealthProduct/)
    end
  end

  context 'caching behavior' do
    it 'caches products after the first call' do
      expect(described_class.products_for_date).to be_empty

      result1 = subject.call(**params)
      expect(result1.success?).to be_truthy
      expect(described_class.products_for_date).not_to be_empty

      cached_products = described_class.products_for_date.clone

      result2 = subject.call(**params)
      expect(result2.success?).to be_truthy
      expect(described_class.products_for_date).to eq(cached_products)
    end

    it 'avoids unnecessary database queries when cache is used' do
      allow(BenefitMarkets::Products::Product).to receive(:by_application_period).and_call_original

      subject.call(**params)
      expect(BenefitMarkets::Products::Product).to have_received(:by_application_period).once

      subject.call(**params)
      expect(BenefitMarkets::Products::Product).to have_received(:by_application_period).once
    end

    it 'clears cached data after reset' do
      subject.call(**params)
      expect(described_class.products_for_date).not_to be_empty

      described_class.reset_data
      expect(described_class.products_for_date).to be_empty
    end
  end
end
