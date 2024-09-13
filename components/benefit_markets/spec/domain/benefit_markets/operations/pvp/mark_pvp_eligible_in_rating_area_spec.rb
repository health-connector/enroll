# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BenefitMarkets::Operations::Pvp::MarkPvpEligibleInRatingArea, type: :operation, dbclean: :after_each do
  let!(:site)            { FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :with_benefit_market_catalog_and_product_packages, :as_hbx_profile, Settings.site.key) }
  let(:effective_date)   { TimeKeeper.date_of_record.beginning_of_year }
  let(:catalog)          { site.benefit_markets[0].benefit_market_catalogs[0] }
  let(:product)          { catalog.product_packages[0].products.first }
  let(:user)             { FactoryBot.create(:user) }

  let(:rating_area) do
    r = product.premium_tables.first.rating_area
    r.update!(exchange_provided_code: "R-MA002")
    r
  end

  let(:operation) { described_class.new }
  let(:params) do
    {
      hios_id: product.hios_id,
      active_year: product.active_year,
      rating_area_code: rating_area.exchange_provided_code[-1],
      evidence_value: true,
      updated_by: user.email
    }
  end

  describe '#call' do
    context 'when params are valid' do
      it 'returns a successful result' do
        result = operation.call(params)
        expect(result).to be_success
        expect(result.success).to be_a(BenefitMarkets::PvpEligibilities::PvpEligibility)
      end
    end

    context 'when validation fails' do
      let(:invalid_params) { params.except(:hios_id)}

      it 'returns a failure result' do
        result = operation.call(invalid_params)
        expect(result).to be_failure
        expect(result.failure).to eq(["HiosId is missing"])
      end
    end
  end
end
