# frozen_string_literal: true

require 'rails_helper'

module BenefitSponsors
  RSpec.describe Datatables::CoverageReportsTable, dbclean: :after_each do
    let!(:site) { FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    let!(:organization) do
      FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site)
    end
    let(:employer_profile) { organization.employer_profile }
    let(:billing_date) { Date.new(2026, 9, 1) }

    subject(:table) { described_class.new(employer_profile, billing_date) }

    describe '#columns' do
      it 'mirrors the legacy BenefitSponsorsCoverageReportsDataTable column order and labels' do
        expect(table.columns.map { |col| col[:name] }).to eq(%w[full_name title coverage_kind cost])
        expect(table.columns.map { |col| col[:label] }).to eq(
          ['Employee Profile', 'Benefit Package', 'Insurance Coverage', 'COST']
        )
      end

      it 'marks no column sortable and flags full_name as pre-ordered' do
        expect(table.columns.none? { |col| col[:sortable] }).to be(true)
        expect(table.columns.select { |col| col[:ordered] }.map { |col| col[:name] }).to eq(['full_name'])
        expect(table.default_order_column).to eq('full_name')
      end

      it 'types every column as a string' do
        expect(table.columns.map { |col| col[:type] }.uniq).to eq([:string])
      end
    end

    describe '#collection' do
      let(:adapter) { BenefitSponsors::LegacyCoverageReportAdapter.new([]) }

      it 'builds the report query for the table employer profile and billing period' do
        expect(BenefitSponsors::Queries::CoverageReportsQuery).to receive(:new)
          .with(employer_profile, billing_date).and_return(instance_double(
                                                             BenefitSponsors::Queries::CoverageReportsQuery, execute: adapter
                                                           ))
        expect(table.collection({})).to eq(adapter)
      end
    end

    # The report's collection adapter no-ops order_by, skip and limit, so the
    # table cannot paginate: every row of the period renders on the first page
    # while the info line and pager still divide the count by the page length.
    describe 'the report collection adapter' do
      subject(:adapter) { BenefitSponsors::LegacyCoverageReportAdapter.new([]) }

      it 'returns itself from order_by, skip and limit' do
        expect(adapter.order_by('full_name' => 1)).to equal(adapter)
        expect(adapter.skip(10)).to equal(adapter)
        expect(adapter.limit(5)).to equal(adapter)
      end

      it 'reports a size the page math can use' do
        expect(adapter.size).to eq(0)
      end
    end

    describe 'product lookups' do
      it 'returns nil for a product or issuer outside the report period' do
        expect(table.product_title(BSON::ObjectId.new)).to be_nil
        expect(table.issuer_name(BSON::ObjectId.new)).to be_nil
      end
    end

    describe 'chrome configuration' do
      it 'renders the search box but no filter tabs or date filter' do
        expect(table.global_search?).to be(true)
        expect(table.filters).to be_nil
        expect(table.filter_scopes).to eq([])
        expect(table.date_filter).to be_nil
      end

      it 'renders no export buttons: the page CSV is its own Download button' do
        expect(table.buttons).to eq([])
      end

      it 'renders no bulk actions' do
        expect(table.bulk_actions).to eq([])
      end

      it 'uses the search-only grid arrangement' do
        expect(table.layout).to eq(::Datatables::Layouts::SEARCH_ONLY)
      end

      it 'offers an unlimited page length' do
        expect(table.per_page_options).to eq([10, 25, 50, ::Datatables::FragmentRendering::ALL_PER_PAGE])
      end
    end
  end
end
