# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Datatables::BrokerAgenciesTable, dbclean: :after_each do
  subject(:table) { described_class.new }

  describe '#columns' do
    it 'mirrors the legacy BrokerAgencyDatatable column order and labels' do
      expect(table.columns.map { |col| col[:name] }).to eq(
        %w[legal_name dba fein entity_kind market_kind]
      )
      expect(table.columns.map { |col| col[:label] }).to eq(
        ['Legal Name', 'Dba', 'FEIN', 'Entity Kind', 'Market Kind']
      )
    end

    it 'marks no column sortable' do
      expect(table.columns.none? { |col| col[:sortable] }).to be(true)
    end

    it 'flags legal_name as the pre-ordered column carrying the sort indicator' do
      ordered = table.columns.select { |col| col[:ordered] }.map { |col| col[:name] }
      expect(ordered).to eq(['legal_name'])
    end
  end

  describe '#collection' do
    let!(:zeta_brokerage) do
      FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_site,
                        :with_broker_agency_profile, legal_name: 'Zeta Brokerage')
    end
    let!(:alpha_brokerage) do
      FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_site,
                        :with_broker_agency_profile, legal_name: 'Alpha Brokerage')
    end
    let!(:hbx_organization) do
      FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_site,
                        :with_hbx_profile, legal_name: 'Not A Brokerage')
    end

    it 'returns only broker agency organizations, pre-sorted by legal name' do
      expect(table.collection({}).map(&:legal_name)).to eq(['Alpha Brokerage', 'Zeta Brokerage'])
    end

    it 'ignores the filter attributes, like the legacy single-tab datatable' do
      expect(table.collection(broker_agencies: 'all').map(&:legal_name)).to eq(['Alpha Brokerage', 'Zeta Brokerage'])
    end

    it 'is a plain Mongoid criteria supporting the datatable_search scope' do
      expect(table.collection({}).datatable_search('Zeta').map(&:legal_name)).to eq(['Zeta Brokerage'])
    end
  end

  describe '#filters' do
    it 'reproduces the legacy single-tab filter definition' do
      expect(table.filters[:top_scope]).to eq(:broker_agencies)
      expect(table.filters[:broker_agencies].map { |filter| filter[:scope] }).to eq(['all'])
    end
  end

  describe 'csv export' do
    let(:organization) do
      FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_site,
                        :with_broker_agency_profile, legal_name: 'Acme Brokers', dba: 'Acme')
    end

    it 'includes every column in the headers' do
      expect(table.csv_headers).to eq(['Legal Name', 'Dba', 'FEIN', 'Entity Kind', 'Market Kind'])
    end

    it 'renders the same plain-text values the table cells show' do
      expect(table.csv_row(organization)).to eq(
        ['Acme Brokers', 'Acme', organization.fein, 'C Corporation', 'Shop']
      )
    end
  end
end
