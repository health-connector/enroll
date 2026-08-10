# frozen_string_literal: true

require 'rails_helper'

module SponsoredBenefits
  RSpec.describe Datatables::PlanDesignEmployeesTable, type: :model do
    let(:benefit_sponsorship) { double(:benefit_sponsorship, id: BSON::ObjectId.new) }
    let(:profile) { double(:profile, benefit_sponsorships: [benefit_sponsorship]) }
    let(:plan_design_proposal) { double(:plan_design_proposal, id: BSON::ObjectId.new, to_param: '5e4461b107f01143707de84e', profile: profile) }

    subject(:table) { described_class.new(plan_design_proposal) }

    describe '#columns' do
      it 'mirrors the legacy PlanDesignEmployeeDatatable column order and labels' do
        expect(table.columns.map { |col| col[:name] }).to eq(
          %w[bulk_actions employee_name dob hired_on status est_participation actions]
        )
        expect(table.columns.map { |col| col[:label] }).to eq(
          ['', 'Employee Name', 'DOB', 'Hired On', 'Status', 'Est Participation', '']
        )
      end

      it 'leads with the checkbox column and its check-all header' do
        expect(table.columns.first).to include(name: 'bulk_actions', type: :bulk_actions_column, header: :bulk_all)
      end

      it 'marks no column sortable and flags employee_name as pre-ordered' do
        expect(table.columns.none? { |col| col[:sortable] }).to be(true)
        expect(table.columns.select { |col| col[:ordered] }.map { |col| col[:name] }).to eq(['employee_name'])
        expect(table.default_order_column).to eq('employee_name')
      end

      it 'gives employee_name and actions the legacy widths' do
        expect(table.columns.find { |col| col[:name] == 'employee_name' }[:width]).to eq('50px')
        expect(table.columns.last[:width]).to eq('50px')
      end

      context 'when the individual market is enabled' do
        before { allow(table).to receive(:individual_market_is_enabled?).and_return(true) }

        it 'drops the est_participation column' do
          expect(table.show_est_participation?).to be(false)
          expect(table.columns.map { |col| col[:name] }).not_to include('est_participation')
        end
      end

      context 'when the individual market is disabled' do
        before { allow(table).to receive(:individual_market_is_enabled?).and_return(false) }

        it 'keeps the est_participation column' do
          expect(table.show_est_participation?).to be(true)
          expect(table.columns.map { |col| col[:name] }).to include('est_participation')
        end
      end
    end

    describe '#collection' do
      it 'passes the filter attributes and the proposal sponsorship to the query wrapper' do
        expect(Queries::PlanDesignEmployeeQuery).to receive(:new).with(
          { employees: 'by_cobra', id: benefit_sponsorship.id }
        )
        table.collection(employees: 'by_cobra')
      end

      it 'always scopes to the proposal sponsorship, ignoring any supplied id' do
        expect(Queries::PlanDesignEmployeeQuery).to receive(:new).with({ id: benefit_sponsorship.id })
        table.collection(id: BSON::ObjectId.new)
      end

      it 'resolves the sponsorship from the proposal profile' do
        expect(table.benefit_sponsorship).to eq(benefit_sponsorship)
      end
    end

    describe '#filters' do
      it 'maps the four roster tabs to the query wrapper scopes, without the commented-out Terminated tab' do
        expect(table.filters[:top_scope]).to eq(:employees)
        expect(table.filters[:employees].map { |tab| tab[:scope] }).to eq(%w[active_alone active by_cobra all])
        expect(table.filters[:employees].map { |tab| tab[:label] }).to eq(
          ['Active only', 'Active & COBRA', 'COBRA only', 'All']
        )
        expect(table.filters[:employees].map { |tab| tab[:scope] }).not_to include('terminated')
        expect(table.filter_scopes).to eq([:employees])
      end
    end

    describe '#bulk_actions' do
      it 'offers the three expected-selection actions in the legacy order' do
        expect(table.bulk_actions.map { |action| action[:label] }).to eq(
          ['Employee will enroll',
           'Employee will not enroll with valid waiver',
           'Employee will not enroll with invalid waiver']
        )
      end

      it 'posts each action to the proposal expected-selection endpoint with its own selection' do
        expect(table.bulk_actions.map { |action| action[:url] }).to eq(
          %w[enroll waive will_not_participate].map do |selection|
            SponsoredBenefits::Engine.routes.url_helpers.expected_selection_plan_design_proposal_plan_design_census_employees_path(
              plan_design_proposal, expected_selection: selection
            )
          end
        )
      end

      it 'carries the legacy confirmation copy' do
        expect(table.bulk_actions.map { |action| action[:confirm] }).to eq(
          ['These employees will be used to estimate your group size and participation rate',
           'Remember, your group size can affect your premium rates',
           'Remember, your participation rate can affect your group premium rates']
        )
      end
    end

    describe '#layout' do
      it 'uses the roster arrangement rather than a shared one' do
        expect(table.layout).not_to eq(::Datatables::Layouts::STANDARD)
        expect(table.layout).not_to eq(::Datatables::Layouts::SEARCH_ONLY)
      end

      it 'places the buttons in the left cell and leaves the right one empty' do
        expect(table.layout.first).to eq(
          [{ class: 'col-sm-7 col-md-7', features: [:buttons] },
           { class: 'col-sm-5 col-md-5', features: [] }]
        )
      end

      it 'renders no processing panel and no search cell' do
        features = table.layout.flatten.flat_map { |cell| cell[:features] }
        expect(features).not_to include(:processing)
        expect(features).not_to include(:search)
      end

      it 'lays the table, info, length and pager out in the legacy column widths' do
        expect(table.layout.map { |row| row.map { |cell| cell[:class] } }).to eq(
          [['col-sm-7 col-md-7', 'col-sm-5 col-md-5'],
           ['col-sm-12 col-md-12'],
           ['col-sm-11 col-md-11', 'col-sm-1 col-md-1'],
           ['col-sm-10 col-md-10', 'col-sm-1 col-md-1'],
           ['col-sm-12 col-md-12']]
        )
      end
    end

    describe 'chrome configuration' do
      it 'renders no search box' do
        expect(table.global_search?).to be(false)
      end

      it 'renders no export buttons: the roster hid them' do
        expect(table.buttons).to eq([])
      end

      it 'renders no date filter' do
        expect(table.date_filter).to be_nil
      end

      it 'leaves selectric alone and numbers columns from zero' do
        expect(table.disable_selectric?).to be(false)
        expect(table.column_index_offset).to eq(0)
      end

      it 'uses the default page length menu' do
        expect(table.per_page_options).to eq([10, 25, 50, 100])
      end

      it 'implements no CSV methods, having no export button' do
        expect(table).not_to respond_to(:csv_headers)
        expect(table).not_to respond_to(:csv_row)
      end
    end
  end
end
