# frozen_string_literal: true

require 'rails_helper'

module BenefitMarkets
  RSpec.describe Services::PvpEligibilityService, type: :service, :dbclean => :after_each do
    let!(:site)            { FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :with_benefit_market_catalog_and_product_packages, :as_hbx_profile, Settings.site.key) }
    let(:effective_date)   { TimeKeeper.date_of_record.beginning_of_year }
    let(:catalog)          { site.benefit_markets[0].benefit_market_catalogs[0] }
    let(:product)          { catalog.product_packages[0].products.first }
    let(:rating_area_1)    { product.premium_tables.first.rating_area }
    let(:rating_area_2)    { create_default(:benefit_markets_locations_rating_area) }
    let(:user)             { FactoryBot.create(:user) }
    let(:args) do
      {
        effective_date: TimeKeeper.date_of_record,
        rating_areas: { rating_area_1.id => 'true', rating_area_2.id => 'true' }
      }
    end

    describe '#create_or_update_pvp_eligibilities' do
      it "when called with single rating area" do
        service = BenefitMarkets::Services::PvpEligibilityService.new(product, user, {rating_areas: {rating_area_1.id => true}})
        service.create_or_update_pvp_eligibilities
        expect(BenefitMarkets::Products::PremiumValueProduct.all.count).to eq 1
        pvp = BenefitMarkets::Products::PremiumValueProduct.all.last
        expect(pvp.pvp_eligibilities.count).to eq 1
      end

      context 'when called with multiple rating areas' do
        it 'iterates through each rating area and processes the eligibility' do
          service = BenefitMarkets::Services::PvpEligibilityService.new(product, user, args)
          result = service.create_or_update_pvp_eligibilities
          expect(result).to eq({ 'Success' => [rating_area_1.id, rating_area_2.id]})
          expect(BenefitMarkets::Products::PremiumValueProduct.all.count).to eq 2
        end
      end

      context 'when an existing eligibility is found with the same evidence value' do
        let(:args) do
          {
            effective_date: TimeKeeper.date_of_record,
            rating_areas: { rating_area_2.id => 'false' }
          }
        end

        before do
          allow_any_instance_of(::Eligible::Eligibility).to receive(:eligible?).and_return(false)
        end

        it 'skips updating eligibility for that rating area' do
          service = BenefitMarkets::Services::PvpEligibilityService.new(product, user, args)
          result = service.create_or_update_pvp_eligibilities
          expect(result).to eq({})
        end
      end

      context 'when an existing eligibility is found with a different evidence value' do
        it 'updates eligibility and creates new state history' do
          service = BenefitMarkets::Services::PvpEligibilityService.new(product, user, {rating_areas: {rating_area_1.id => true}})
          service.create_or_update_pvp_eligibilities
          expect(BenefitMarkets::Products::PremiumValueProduct.all.count).to eq 1
          pvp = BenefitMarkets::Products::PremiumValueProduct.all.last
          expect(pvp.pvp_eligibilities.count).to eq 1
          expect(pvp.pvp_eligibilities.first.eligible?).to eq true
          expect(pvp.pvp_eligibilities.first.state_histories.count).to eq 1

          service = BenefitMarkets::Services::PvpEligibilityService.new(product, user, {rating_areas: {rating_area_1.id => false}})
          service.create_or_update_pvp_eligibilities
          expect(BenefitMarkets::Products::PremiumValueProduct.all.count).to eq 1
          expect(pvp.reload.pvp_eligibilities.count).to eq 1
          expect(pvp.pvp_eligibilities.first.eligible?).to eq false
          expect(pvp.pvp_eligibilities.first.state_histories.count).to eq 2
        end
      end
    end

    describe '#find_or_create_pvp' do
      context 'when successful' do
        it 'returns Success with the PVP' do
          pvp = BenefitMarkets::Products::PremiumValueProduct.create(product_id: product.id, rating_area_id: rating_area_1.id)
          service = described_class.new(product, user)
          result = service.find_or_create_pvp(rating_area_1.id)
          expect(result).to eq(pvp)
        end
      end

      context 'when fails' do
        it 'returns Failure with errors if rating_area_id is missing' do
          service = described_class.new(product, user)
          result = service.find_or_create_pvp(nil)
          expect(result).to be_nil
        end
      end
    end
  end
end
