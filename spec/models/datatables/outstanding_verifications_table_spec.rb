# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Datatables::OutstandingVerificationsTable, dbclean: :after_each do
  subject(:table) { described_class.new }

  describe '#columns' do
    it 'mirrors the legacy OutstandingVerificationDataTable column order and labels' do
      expect(table.columns.map { |col| col[:name] }).to eq(
        %w[name ssn dob hbx_id count documents_uploaded verification_due actions]
      )
      expect(table.columns.map { |col| col[:label] }).to eq(
        ['Name', 'SSN', 'DOB', 'HBX ID', 'Count', 'Documents Uploaded', 'Verification Due', 'Actions']
      )
    end

    it 'marks name, documents_uploaded, and verification_due sortable (matching the legacy flags)' do
      expect(table.columns.select { |col| col[:sortable] }.map { |col| col[:name] }).to eq(
        %w[name documents_uploaded verification_due]
      )
    end

    it 'types hbx_id as integer for the col-integer class' do
      expect(table.columns.find { |col| col[:name] == 'hbx_id' }[:type]).to eq(:integer)
    end
  end

  describe '#collection' do
    it 'wraps the filter attributes in the legacy OutstandingVerificationDatatableQuery' do
      collection = table.collection(documents_uploaded: 'vlp_partially_uploaded',
                                    custom_datatable_date_from: '2026-01-01',
                                    custom_datatable_date_to: '2026-12-31')
      expect(collection).to be_a(Queries::OutstandingVerificationDatatableQuery)
      expect(collection.custom_attributes).to eq(
        documents_uploaded: 'vlp_partially_uploaded',
        custom_datatable_date_from: '2026-01-01',
        custom_datatable_date_to: '2026-12-31'
      )
    end
  end

  describe '#filters' do
    it 'reproduces the legacy documents-uploaded filter definition' do
      expect(table.filters[:top_scope]).to eq(:documents_uploaded)
      expect(table.filters[:documents_uploaded].map { |filter| filter[:scope] }).to eq(
        %w[vlp_fully_uploaded vlp_partially_uploaded vlp_none_uploaded all]
      )
    end
  end

  describe '#filter_scopes' do
    it 'carries the documents-uploaded tab and both date-range params to the query wrapper' do
      expect(table.filter_scopes).to eq([:documents_uploaded, :custom_datatable_date_from, :custom_datatable_date_to])
    end
  end

  describe '#date_filter' do
    it 'is the verification-due date range label' do
      expect(table.date_filter).to eq('Verification Due Date Range')
    end
  end

  describe '#buttons' do
    it 'renders excel, csv, and print in the legacy order' do
      expect(table.buttons).to eq(%w[excel csv print])
    end
  end

  describe '#per_page_options' do
    it 'omits the 100 option, matching the legacy lengthMenu [[10,25,50],[10,25,50]]' do
      expect(table.per_page_options).to eq([10, 25, 50])
    end
  end

  describe 'csv export' do
    # ssn must be a mutable string: number_to_ssn formats it in place with gsub!,
    # just as it does on the real (unfrozen) Mongoid Person#ssn value.
    let(:person) { double('person', full_name: 'Jane Doe', ssn: +'123456789', dob: Date.new(1985, 3, 2), hbx_id: '55555') }
    let(:primary_applicant) { double('primary_applicant', person: person) }
    let(:family) do
      double('family',
             primary_applicant: primary_applicant,
             active_family_members: [double, double, double],
             vlp_documents_status: 'Partially Uploaded',
             best_verification_due_date: Date.new(2026, 7, 1))
    end

    it 'excludes the actions column from the headers' do
      expect(table.csv_headers).to eq(['Name', 'SSN', 'DOB', 'HBX ID', 'Count', 'Documents Uploaded', 'Verification Due'])
    end

    it 'renders the same plain-text values the table cells show' do
      expect(table.csv_row(family)).to eq(
        ['Jane Doe', '***-**-6789', '03/02/1985', '55555', 3, 'Partially Uploaded', '07/01/2026']
      )
    end

    it 'falls back to today + 95 days when there is no best verification due date' do
      allow(family).to receive(:best_verification_due_date).and_return(nil)
      fallback = ApplicationController.helpers.format_date(TimeKeeper.date_of_record + 95.days)
      expect(table.csv_row(family).last).to eq(fallback)
    end
  end
end
