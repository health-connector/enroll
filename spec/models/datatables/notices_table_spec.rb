# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Datatables::NoticesTable, type: :model, dbclean: :after_each do
  subject(:table) { described_class.new }

  describe '#columns' do
    it 'mirrors the legacy NoticesDatatable column order and labels' do
      expect(table.columns.map { |col| col[:name] }).to eq(
        %w[bulk_actions mpi_indicator title description recipient last_updated_at actions]
      )
      expect(table.columns.map { |col| col[:label] }).to eq(
        ['', 'Mpi Indicator', 'Title', 'Description', 'Recipient', 'Last Updated At', 'Actions']
      )
    end

    it 'leads with the checkbox column and its check-all header' do
      expect(table.columns.first).to include(name: 'bulk_actions', type: :bulk_actions_column, header: :bulk_all)
    end

    it 'marks no column sortable and flags mpi_indicator as pre-ordered' do
      expect(table.columns.none? { |col| col[:sortable] }).to be(true)
      expect(table.columns.select { |col| col[:ordered] }.map { |col| col[:name] }).to eq(['mpi_indicator'])
      expect(table.default_order_column).to eq('mpi_indicator')
    end

    it 'gives the actions column the legacy width' do
      expect(table.columns.last[:width]).to eq('50px')
    end
  end

  describe '#collection' do
    let!(:notice_kind) do
      Notifier::NoticeKind.create!(notice_number: 'DR900', title: 'A Notice', description: 'A description',
                                   recipient: 'Notifier::MergeDataModels::EmployerProfile', event_name: 'a_notice_event')
    end

    it 'returns every notice kind, ignoring the filter attributes' do
      expect(table.collection({}).to_a).to include(notice_kind)
      expect(table.collection(anything: 'ignored').to_a).to eq(table.collection({}).to_a)
    end
  end

  describe '#bulk_actions' do
    it 'offers only Delete, posting to the notifier endpoint with the legacy confirmation' do
      expect(table.bulk_actions).to eq(
        [{ label: 'Delete',
           url: Notifier::Engine.routes.url_helpers.delete_notices_notice_kinds_path,
           confirm: 'This will remove selected notices. Are you sure?' }]
      )
    end

    it 'does not offer the commented-out Download action' do
      expect(table.bulk_actions.map { |action| action[:label] }).not_to include('Download')
    end
  end

  describe 'row cell values' do
    let(:notice_kind) do
      double(:notice_kind, recipient_klass_name: 'employer_profile',
                           updated_at: Time.utc(2026, 8, 10, 17, 21))
    end

    it 'titleizes the recipient class name' do
      expect(table.recipient(notice_kind)).to eq('Employer Profile')
    end

    it 'renders the update time in Eastern Time' do
      expect(table.last_updated_at(notice_kind)).to eq('08/10/2026 13:21')
    end
  end

  describe 'CSV export' do
    it 'omits the checkbox and actions columns from the headers' do
      expect(table.csv_headers).to eq(['Mpi Indicator', 'Title', 'Description', 'Recipient', 'Last Updated At'])
    end

    it 'exports the notice number the glyph column links to' do
      row = double(:notice_kind, notice_number: 'DR001', title: 'A Notice', description: 'A description')
      allow(table).to receive_messages(recipient: 'Employer Profile', last_updated_at: '08/10/2026 13:21')
      expect(table.csv_row(row)).to eq(['DR001', 'A Notice', 'A description', 'Employer Profile', '08/10/2026 13:21'])
      expect(table.csv_row(row).size).to eq(table.csv_headers.size)
    end
  end

  describe 'chrome configuration' do
    it 'renders no search box' do
      expect(table.global_search?).to be(false)
    end

    it 'renders no filter tabs and no date filter' do
      expect(table.filters).to be_nil
      expect(table.filter_scopes).to eq([])
      expect(table.date_filter).to be_nil
    end

    it 'renders the default export buttons' do
      expect(table.buttons).to eq(%w[csv excel])
    end

    it 'uses the standard grid arrangement and page length menu' do
      expect(table.layout).to eq(Datatables::Layouts::STANDARD)
      expect(table.per_page_options).to eq([10, 25, 50, 100])
    end

    it 'leaves selectric alone and numbers columns from zero' do
      expect(table.disable_selectric?).to be(false)
      expect(table.column_index_offset).to eq(0)
    end
  end
end
