# frozen_string_literal: true

require 'rails_helper'

describe Services::PlanValidationReport, :dbclean => :after_each do
  let(:report) { described_class.new(Date.new(2019, 12, 1)) }
  let(:plan_year_period) { Time.utc(2019, 1, 1)..Time.utc(2019, 12, 31) }
  let(:issuer_profile) do
    profile = FactoryBot.create(:benefit_sponsors_organizations_exempt_organization, :with_issuer_profile).issuer_profile
    profile.update(abbrev: "TEST", issuer_hios_ids: ["88888", "52710"])
    profile
  end

  def create_product(hios_prefix)
    FactoryBot.create(
      :benefit_markets_products_health_products_health_product,
      issuer_profile_id: issuer_profile.id,
      application_period: plan_year_period,
      benefit_market_kind: :aca_shop,
      kind: :health,
      product_package_kinds: [:single_issuer],
      hios_id: "#{hios_prefix}MA0100001-01"
    )
  end

  describe '#issuer_hios_ids_for' do
    subject { report.issuer_hios_ids_for(issuer_profile) }

    context 'when only some hios ids have products for the active year' do
      before { create_product("88888") }

      it 'returns only the hios ids that have products, as strings' do
        expect(subject).to eq(["88888"])
      end
    end

    context 'when all hios ids have products for the active year' do
      before do
        create_product("88888")
        create_product("52710")
      end

      it 'returns every hios id' do
        expect(subject).to contain_exactly("88888", "52710")
      end
    end

    context 'when no hios ids have products for the active year' do
      it 'returns an empty array' do
        expect(subject).to eq([])
      end
    end
  end
end
