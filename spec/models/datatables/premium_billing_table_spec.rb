# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Datatables::PremiumBillingTable, dbclean: :after_each do
  let(:employer_profile) { double('EmployerProfile') }
  let(:billing_date) { TimeKeeper.date_of_record.next_month.beginning_of_month }

  subject(:table) { described_class.new(employer_profile, billing_date) }

  describe '#columns' do
    it 'mirrors the legacy PremiumBillingReportDataTable column order and labels' do
      expect(table.columns.map { |col| col[:name] }).to eq(%w[full_name title coverage_kind cost])
      expect(table.columns.map { |col| col[:label] }).to eq(
        ['Employee Profile', 'Benefit Package', 'Insurance Coverage', 'COST']
      )
    end

    it 'marks no column sortable' do
      expect(table.columns.none? { |col| col[:sortable] }).to be(true)
    end

    it 'flags full_name as the pre-ordered column carrying the sort indicator' do
      ordered = table.columns.select { |col| col[:ordered] }.map { |col| col[:name] }
      expect(ordered).to eq(['full_name'])
      expect(table.default_order_column).to eq('full_name')
    end
  end

  describe 'chrome configuration' do
    it 'renders no export button: the report CSV is served by the show action' do
      expect(table.buttons).to eq([])
    end

    it 'offers an unlimited page-length option' do
      expect(table.per_page_options).to eq([10, 25, 50, Datatables::FragmentRendering::ALL_PER_PAGE])
      expect(table.per_page_options.last).to eq(-1)
    end

    it 'keeps its own grid arrangement rather than the standard one' do
      expect(table.layout).not_to eq(Datatables::Layouts::STANDARD)
      expect(table.layout.map { |row| row.map { |cell| cell[:class] } }).to eq(
        [
          ['col-sm-5', 'col-sm-5'],
          ['col-sm-10'],
          ['col-sm-9', 'col-sm-3'],
          ['col-sm-10']
        ]
      )
      expect(table.layout.map { |row| row.map { |cell| cell[:features] } }).to eq(
        [
          [[], [:search]],
          [[:table, :processing]],
          [[:info], [:length]],
          [[:pagination]]
        ]
      )
    end

    it 'renders no filter tab bar and collects no filter params' do
      expect(table.filters).to be_nil
      expect(table.filter_scopes).to eq([])
      expect(table.date_filter).to be_nil
    end

    it 'keeps the search box' do
      expect(table.global_search?).to be(true)
    end
  end

  describe '#hbx_enrollment_ids' do
    let(:statement) { double('EmployerPremiumStatement', hbx_enrollments: [double(_id: 'one'), double(_id: 'two')]) }

    it 'reads the enrollment ids for the selected billing period' do
      allow(Queries::EmployerPremiumStatement).to receive(:new).with(employer_profile, billing_date).and_return(
        double(execute: statement)
      )
      expect(table.hbx_enrollment_ids).to eq(%w[one two])
    end

    it 'is empty when the period has no statement' do
      allow(Queries::EmployerPremiumStatement).to receive(:new).with(employer_profile, billing_date).and_return(
        double(execute: nil)
      )
      expect(table.hbx_enrollment_ids).to eq([])
    end
  end

  describe '#collection' do
    let(:family) { FactoryBot.create(:family, :with_primary_family_member) }
    let(:other_family) { FactoryBot.create(:family, :with_primary_family_member) }
    let!(:health_enrollment) { FactoryBot.create(:hbx_enrollment, household: family.active_household) }
    let!(:dental_enrollment) { FactoryBot.create(:hbx_enrollment, household: family.active_household) }
    let!(:other_familys_enrollment) do
      FactoryBot.create(:hbx_enrollment, household: other_family.active_household)
    end

    def stub_statement(enrollments)
      allow(Queries::EmployerPremiumStatement).to receive(:new).with(employer_profile, billing_date).and_return(
        double(execute: double(hbx_enrollments: enrollments))
      )
    end

    it 'counts families, not enrollments, so the info line matches the legacy count' do
      stub_statement([health_enrollment, dental_enrollment])
      expect(table.collection({}).size).to eq(1)
    end

    it 'expands each page of families into their in-period enrollments' do
      stub_statement([health_enrollment, dental_enrollment])
      rows = table.collection({}).order_by({}).skip(0).limit(10).to_a
      expect(rows.map(&:id)).to match_array([health_enrollment.id, dental_enrollment.id])
    end

    it 'excludes enrollments outside the billing period' do
      stub_statement([health_enrollment])
      rows = table.collection({}).order_by({}).skip(0).limit(10).to_a
      expect(rows.map(&:id)).to eq([health_enrollment.id])
    end

    it 'paginates over families' do
      stub_statement([health_enrollment, dental_enrollment, other_familys_enrollment])
      collection = table.collection({})
      expect(collection.size).to eq(2)
      first_page = collection.order_by({}).skip(0).limit(1).to_a
      expect(first_page.map(&:id)).to match_array([health_enrollment.id, dental_enrollment.id])
    end

    it 'is empty when the period has no enrollments' do
      stub_statement([])
      expect(table.collection({}).size).to eq(0)
      expect(table.collection({}).order_by({}).skip(0).limit(10).to_a).to eq([])
    end

    context 'when the enrollment belongs to an employee role' do
      let(:person) { family.primary_applicant.person }
      let!(:employee_role) { FactoryBot.create(:employee_role, person: person) }

      before do
        health_enrollment.update_attributes!(employee_role_id: employee_role.id)
        stub_statement([health_enrollment])
      end

      it 'narrows by employee name through the query wrapper datatable_search' do
        expect(table.collection({}).datatable_search(person.last_name).size).to eq(1)
      end

      it 'drops the family when no employee name matches' do
        expect(table.collection({}).datatable_search('ZzzNoSuchEmployee').size).to eq(0)
      end
    end
  end
end
