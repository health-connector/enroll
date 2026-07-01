# frozen_string_literal: true

require 'rails_helper'

describe Services::PlanValidationReport, :dbclean => :after_each do
  let(:active_date) { Date.new(2019, 12, 1) }
  let(:report) { Services::PlanValidationReport.new(active_date) }
  let(:start_date) { Date.new(2019, 1, 1) }
  let(:end_date) { Date.new(2019, 12, 31) }
  let(:application_period) do
    (Time.utc(start_date.year, start_date.month, start_date.day)..
      Time.utc(end_date.year, end_date.month, end_date.day))
  end

  describe '#issuer_hios_ids_for' do
    context 'when issuer profile has multiple hios ids and only one has products' do
      let(:issuer_org) do
        FactoryBot.create(:benefit_sponsors_organizations_exempt_organization, :with_issuer_profile)
      end
      let(:issuer_profile) { issuer_org.issuer_profile }

      before do
        issuer_profile.update(
          abbrev: "TEST",
          issuer_hios_ids: ["88888", "52710"]
        )

        # Create product for hios_id 88888 only
        FactoryBot.create(
          :benefit_markets_products_health_products_health_product,
          issuer_profile_id: issuer_profile.id,
          application_period: application_period,
          benefit_market_kind: :aca_shop,
          kind: :health,
          product_package_kinds: [:single_issuer],
          hios_id: "88888MA0100001-01"
        )
      end

      it 'excludes hios_ids without products for the active year' do
        hios_ids = report.issuer_hios_ids_for(issuer_profile)
        expect(hios_ids).to eq(["88888"])
      end

      it 'returns hios_ids as strings' do
        hios_ids = report.issuer_hios_ids_for(issuer_profile)
        expect(hios_ids).to all(be_a(String))
      end
    end

    context 'when issuer profile has multiple hios ids with products for both' do
      let(:issuer_org) do
        FactoryBot.create(:benefit_sponsors_organizations_exempt_organization, :with_issuer_profile)
      end
      let(:issuer_profile) { issuer_org.issuer_profile }

      before do
        issuer_profile.update(
          abbrev: "TEST",
          issuer_hios_ids: ["88888", "52710"]
        )

        # Create product for hios_id 88888
        FactoryBot.create(
          :benefit_markets_products_health_products_health_product,
          issuer_profile_id: issuer_profile.id,
          application_period: application_period,
          benefit_market_kind: :aca_shop,
          kind: :health,
          product_package_kinds: [:single_issuer],
          hios_id: "88888MA0100001-01"
        )

        # Create product for hios_id 52710
        FactoryBot.create(
          :benefit_markets_products_health_products_health_product,
          issuer_profile_id: issuer_profile.id,
          application_period: application_period,
          benefit_market_kind: :aca_shop,
          kind: :health,
          product_package_kinds: [:single_issuer],
          hios_id: "52710MA0100001-01"
        )
      end

      it 'includes all hios_ids that have products for the active year' do
        hios_ids = report.issuer_hios_ids_for(issuer_profile)
        expect(hios_ids).to contain_exactly("88888", "52710")
      end
    end

    context 'when issuer profile has no products for the active year' do
      let(:issuer_org) do
        FactoryBot.create(:benefit_sponsors_organizations_exempt_organization, :with_issuer_profile)
      end
      let(:issuer_profile) { issuer_org.issuer_profile }

      before do
        issuer_profile.update(
          abbrev: "TEST",
          issuer_hios_ids: ["88888", "52710"]
        )
        # Do not create any products
      end

      it 'returns empty array' do
        hios_ids = report.issuer_hios_ids_for(issuer_profile)
        expect(hios_ids).to eq([])
      end
    end
  end
end
