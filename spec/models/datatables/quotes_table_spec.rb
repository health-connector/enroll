# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Datatables::QuotesTable, dbclean: :after_each do
  let(:broker_role) { FactoryBot.create(:broker_role) }
  let(:other_broker_role) { FactoryBot.create(:broker_role) }

  subject(:table) { described_class.new(broker_role.id) }

  describe '#columns' do
    it 'mirrors the legacy QuoteDatatable column order and labels' do
      expect(table.columns.map { |col| col[:name] }).to eq(
        %w[employer_name employer_type quote effective_date claim_code family_count state actions]
      )
      expect(table.columns.map { |col| col[:label] }).to eq(
        ['Employer Name', 'Employer Type', 'Quote', 'Effective Date', 'Claim Code', 'Family Count', 'State', 'Actions']
      )
    end

    it 'marks no column sortable' do
      expect(table.columns.none? { |col| col[:sortable] }).to be(true)
    end

    it 'flags employer_name as the pre-ordered column carrying the sort indicator' do
      ordered = table.columns.select { |col| col[:ordered] }.map { |col| col[:name] }
      expect(ordered).to eq(['employer_name'])
      expect(table.default_order_column).to eq('employer_name')
    end

    it 'types every column as a string, as the legacy table did' do
      expect(table.columns.map { |col| col[:type] }.uniq).to eq([:string])
    end
  end

  describe '#collection' do
    let!(:draft_quote) do
      FactoryBot.create(:quote, broker_role_id: broker_role.id, quote_name: 'Draft Quote',
                                employer_type: 'prospect', aasm_state: 'draft')
    end
    let!(:published_quote) do
      FactoryBot.create(:quote, broker_role_id: broker_role.id, quote_name: 'Published Quote',
                                employer_type: 'prospect', aasm_state: 'published')
    end
    let!(:client_quote) do
      FactoryBot.create(:quote, broker_role_id: broker_role.id, quote_name: 'Client Quote',
                                employer_type: 'client', aasm_state: 'draft')
    end
    let!(:other_brokers_quote) do
      FactoryBot.create(:quote, broker_role_id: other_broker_role.id, quote_name: 'Someone Elses Quote',
                                employer_type: 'prospect', aasm_state: 'draft')
    end

    it 'returns only the quotes belonging to the table broker' do
      expect(table.collection({}).map(&:quote_name)).to match_array(['Draft Quote', 'Published Quote', 'Client Quote'])
    end

    it 'ignores an all selection on either tab level' do
      expect(table.collection(employer_types: 'all', states: 'all').map(&:quote_name)).to match_array(
        ['Draft Quote', 'Published Quote', 'Client Quote']
      )
    end

    it 'narrows to the selected employer type' do
      expect(table.collection(employer_types: 'prospect').map(&:quote_name)).to match_array(['Draft Quote', 'Published Quote'])
    end

    it 'narrows to the selected state within an employer type' do
      expect(table.collection(employer_types: 'prospect', states: 'draft').map(&:quote_name)).to eq(['Draft Quote'])
    end

    it 'ignores a state that is not one of the tab scopes' do
      expect(table.collection(employer_types: 'prospect', states: 'nonsense').map(&:quote_name)).to match_array(
        ['Draft Quote', 'Published Quote']
      )
    end

    it 'is a plain Mongoid criteria supporting the quote-name datatable_search scope' do
      expect(table.collection({}).datatable_search('Published').map(&:quote_name)).to eq(['Published Quote'])
    end
  end

  describe '#filters' do
    it 'reproduces the legacy nested employer_types filter definition' do
      expect(table.filters[:top_scope]).to eq(:employer_types)
      expect(table.filters[:employer_types].map { |filter| filter[:scope] }).to eq(%w[all prospect])
      expect(table.filters[:employer_types].last[:subfilter]).to eq(:states)
      expect(table.filters[:states].map { |filter| filter[:scope] }).to eq(%w[all draft published claimed])
    end

    it 'collects both tab levels into the collection attributes' do
      expect(table.filter_scopes).to eq([:employer_types, :states])
    end
  end

  describe '#published_quote_link_type' do
    it 'disables the published-quote action while the quote is a draft' do
      quote = FactoryBot.create(:quote, broker_role_id: broker_role.id, aasm_state: 'draft')
      expect(table.published_quote_link_type(quote)).to eq('disabled')
    end

    it 'enables the published-quote action once the quote leaves draft' do
      quote = FactoryBot.create(:quote, broker_role_id: broker_role.id, aasm_state: 'published')
      expect(table.published_quote_link_type(quote)).to eq('static')
    end
  end

  describe '#employer_name' do
    it 'falls back to the prospect employer name when there is no employer profile' do
      quote = FactoryBot.create(:quote, broker_role_id: broker_role.id, employer_name: 'Northwind Traders')
      expect(table.employer_name(quote)).to eq('Northwind Traders')
    end

    it 'prefers the employer profile legal name when the quote is tied to one' do
      employer_profile = FactoryBot.create(:employer_profile)
      quote = FactoryBot.create(:quote, broker_role_id: broker_role.id, employer_name: 'Ignored',
                                        employer_profile_id: employer_profile.id)
      expect(table.employer_name(quote)).to eq(employer_profile.legal_name)
    end
  end

  describe 'csv export' do
    it 'excludes the actions column from the headers' do
      expect(table.csv_headers).to eq(
        ['Employer Name', 'Employer Type', 'Quote', 'Effective Date', 'Claim Code', 'Family Count', 'State']
      )
    end

    it 'renders the same plain-text values the table cells show' do
      quote = FactoryBot.create(:quote, :with_household_and_members, broker_role_id: broker_role.id,
                                                                     quote_name: 'summer quote', employer_name: 'Northwind Traders',
                                                                     employer_type: 'prospect', aasm_state: 'draft', claim_code: 'AB12-CD34')
      expect(table.csv_row(quote.reload)).to eq(
        ['Northwind Traders', 'prospect', 'Summer Quote', quote.start_on, 'AB12-CD34', 1, 'draft']
      )
    end
  end

  describe 'chrome configuration' do
    it 'renders the default export buttons and page lengths in the standard layout' do
      expect(table.buttons).to eq(%w[csv excel])
      expect(table.per_page_options).to eq([10, 25, 50, 100])
      expect(table.layout).to eq(Datatables::Layouts::STANDARD)
    end

    it 'has no date filter, bulk actions or column offset' do
      expect(table.date_filter).to be_nil
      expect(table.bulk_actions).to eq([])
      expect(table.column_index_offset).to eq(0)
      expect(table.disable_selectric?).to be(false)
    end
  end
end
