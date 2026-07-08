# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Datatables::FamiliesTable, dbclean: :after_each do
  subject(:table) { described_class.new }

  describe '#columns' do
    it 'mirrors the legacy FamilyDataTable column order and labels (SHOP-only: no consumer? column)' do
      expect(table.columns.map { |col| col[:name] }).to eq(
        %w[name ssn dob hbx_id count active_enrollments registered? employee? actions]
      )
      expect(table.columns.map { |col| col[:label] }).to eq(
        ['Name', 'SSN', 'DOB', 'HBX ID', 'Count', 'Active Enrollments?', 'Registered?', 'Employee?', 'Actions']
      )
    end

    it 'marks no column user-sortable and name as the pre-ordered column' do
      expect(table.columns.none? { |col| col[:sortable] }).to be true
      expect(table.columns.find { |col| col[:ordered] }[:name]).to eq('name')
    end

    it 'types hbx_id as integer for the col-integer class' do
      expect(table.columns.find { |col| col[:name] == 'hbx_id' }[:type]).to eq(:integer)
    end
  end

  describe '#collection' do
    it 'wraps the filter attributes in the legacy FamilyDatatableQuery, readable by its string keys' do
      collection = table.collection(families: 'by_enrollment_shop_market', employer_options: 'sep_eligible')
      expect(collection).to be_a(Queries::FamilyDatatableQuery)
      expect(collection.custom_attributes['families']).to eq('by_enrollment_shop_market')
      expect(collection.custom_attributes['employer_options']).to eq('sep_eligible')
    end

    it 'builds the same selector the legacy wrapper builds for the shop-enrolled tab' do
      collection = table.collection(families: 'by_enrollment_shop_market')
      expect(collection.build_scope.selector).to eq(
        Queries::FamilyDatatableQuery.new({ 'families' => 'by_enrollment_shop_market' }).build_scope.selector
      )
    end
  end

  describe '#filters' do
    it 'reproduces the legacy families filter tree (SHOP-only: no Individual Enrolled branch)' do
      expect(table.filters[:top_scope]).to eq(:families)
      expect(table.filters[:families].map { |filter| filter[:scope] }).to eq(
        %w[all by_enrollment_shop_market non_enrolled]
      )
      expect(table.filters[:families].map { |filter| filter[:label] }).to eq(
        ['All', 'Employer Sponsored Coverage Enrolled', 'Non Enrolled']
      )
      expect(table.filters[:families][1][:subfilter]).to eq(:employer_options)
    end

    it 'keeps the legacy employer_options scopes, including the no-op enrolled and waived tabs' do
      expect(table.filters[:employer_options].map { |filter| filter[:scope] }).to eq(
        %w[all enrolled by_enrollment_renewing waived sep_eligible]
      )
    end
  end

  describe '#filter_scopes' do
    it 'carries all three tab scopes to the query wrapper' do
      expect(table.filter_scopes).to eq([:families, :employer_options, :individual_options])
    end
  end

  describe 'contract defaults' do
    it 'implements the shared-table contract with the legacy Families settings' do
      expect(table.param_key).to eq('families')
      expect(table.global_search?).to be true
      expect(table.date_filter).to be_nil
      expect(table.default_order_column).to eq('name')
      expect(table.column_index_offset).to eq(0)
      expect(table.bulk_actions).to eq([])
      expect(table.disable_selectric?).to be false
      expect(table.buttons).to eq(%w[csv excel])
      expect(table.per_page_options).to eq([10, 25, 50, 100])
      expect(table.row_partial).to eq('exchanges/hbx_profiles/datatables/families_row')
    end
  end

  describe 'csv export' do
    # ssn must be a mutable string: number_to_ssn formats it in place with gsub!,
    # just as it does on the real (unfrozen) Mongoid Person#ssn value.
    let(:person) do
      double('person', full_name: 'Jane Doe', ssn: +'123456789', dob: Date.new(1985, 3, 2),
                       hbx_id: '55555', user: double('user'), active_employee_roles: [double])
    end
    let(:primary_applicant) { double('primary_applicant', person: person) }
    let(:enrolled_and_renewing) { [double] }
    let(:active_scope) { double('active', enrolled_and_renewing: enrolled_and_renewing) }
    let(:non_external) { double('non_external', active: active_scope) }
    let(:hbx_enrollments) { double('hbx_enrollments', non_external: non_external) }
    let(:family) do
      double('family',
             primary_applicant: primary_applicant,
             active_family_members: [double, double],
             active_household: double('household', hbx_enrollments: hbx_enrollments))
    end

    it 'excludes the actions column from the headers' do
      expect(table.csv_headers).to eq(
        ['Name', 'SSN', 'DOB', 'HBX ID', 'Count', 'Active Enrollments?', 'Registered?', 'Employee?']
      )
    end

    it 'renders the same plain-text values the table cells show' do
      expect(table.csv_row(family)).to eq(
        ['Jane Doe', '***-**-6789', '03/02/1985', '55555', 2, 'Yes', 'Yes', 'Yes']
      )
    end

    it 'renders No for a family with no active enrollments, no user, and no employee roles' do
      allow(active_scope).to receive(:enrolled_and_renewing).and_return([])
      allow(person).to receive(:user).and_return(nil)
      allow(person).to receive(:active_employee_roles).and_return([])
      expect(table.csv_row(family)[5..7]).to eq(%w[No No No])
    end
  end
end
