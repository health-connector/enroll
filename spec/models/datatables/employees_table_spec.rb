# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application"

RSpec.describe Datatables::EmployeesTable, dbclean: :after_each do
  include_context 'setup benefit market with market catalogs and product packages'
  include_context 'setup initial benefit application'

  let(:employer_profile) { abc_profile }

  subject(:table) { described_class.new(employer_profile) }

  # The renewal / off-cycle column variants are driven purely by these
  # predicates on the employer profile.
  def table_for(renewal: nil, off_cycle: nil, off_cycle_submitted: false, current_terminated: false)
    profile = abc_profile
    allow(profile).to receive(:renewal_benefit_application).and_return(renewal)
    allow(profile).to receive(:off_cycle_benefit_application).and_return(off_cycle)
    allow(off_cycle).to receive(:is_submitted?).and_return(off_cycle_submitted) if off_cycle
    allow(profile).to receive(:current_benefit_application).and_return(double(terminated?: current_terminated))
    described_class.new(profile)
  end

  let(:application) { instance_double(BenefitSponsors::BenefitApplications::BenefitApplication) }

  describe '#columns' do
    it 'mirrors the legacy EmployeeDatatable column order and labels' do
      expect(table.columns.map { |col| col[:name] }).to eq(
        %w[bulk_actions employee_name dob hired_on terminated_on status benefit_package enrollment_status est_participation actions]
      )
      expect(table.columns.map { |col| col[:label] }).to eq(
        ['', 'Employee Name', 'DOB', 'Hired On', 'Terminated On', 'Status', 'Benefit Package', 'Enrollment Status', 'Est Participation', '']
      )
    end

    it 'marks no column sortable' do
      expect(table.columns.none? { |col| col[:sortable] }).to be(true)
    end

    it 'flags employee_name as the pre-ordered column carrying the sort indicator' do
      expect(table.columns.select { |col| col[:ordered] }.map { |col| col[:name] }).to eq(['employee_name'])
      expect(table.default_order_column).to eq('employee_name')
    end

    it 'renders the check-all header on the bulk actions column' do
      bulk_column = table.columns.first
      expect(bulk_column[:type]).to eq(:bulk_actions_column)
      expect(bulk_column[:header]).to eq(:bulk_all)
    end

    it 'shows est_participation while the individual market is off' do
      expect(table.show_est_participation?).to be(true)
      expect(table.columns.map { |col| col[:name] }).to include('est_participation')
    end

    context 'when the employer has a renewal application' do
      subject(:table) { table_for(renewal: application) }

      it 'adds the renewal package and enrollment status columns after their current-year counterparts' do
        expect(table.columns.map { |col| col[:name] }).to eq(
          %w[bulk_actions employee_name dob hired_on terminated_on status benefit_package renewal_benefit_package
             enrollment_status renewal_enrollment_status est_participation actions]
        )
        expect(table.columns.find { |col| col[:name] == 'renewal_benefit_package' }[:label]).to eq('Renewal Benefit Package')
      end
    end

    context 'when the employer has an off-cycle application that is not submitted' do
      subject(:table) { table_for(off_cycle: application, off_cycle_submitted: false) }

      it 'adds the off-cycle package column but not the off-cycle enrollment status' do
        names = table.columns.map { |col| col[:name] }
        expect(names).to include('off_cycle_benefit_package')
        expect(names).not_to include('off_cycle_enrollment_status')
      end
    end

    context 'when the employer has a submitted off-cycle application' do
      subject(:table) { table_for(off_cycle: application, off_cycle_submitted: true) }

      it 'adds both off-cycle columns' do
        expect(table.columns.map { |col| col[:name] }).to eq(
          %w[bulk_actions employee_name dob hired_on terminated_on status benefit_package off_cycle_benefit_package
             enrollment_status off_cycle_enrollment_status est_participation actions]
        )
        expect(table.columns.find { |col| col[:name] == 'off_cycle_benefit_package' }[:label]).to eq('Off-Cycle Benefit Package')
      end
    end

    context 'when the current plan year is terminated alongside an off-cycle application' do
      subject(:table) { table_for(off_cycle: application, off_cycle_submitted: true, current_terminated: true) }

      it 'drops the current-year package and enrollment status columns' do
        names = table.columns.map { |col| col[:name] }
        expect(names).not_to include('benefit_package', 'enrollment_status')
        expect(names).to eq(
          %w[bulk_actions employee_name dob hired_on terminated_on status off_cycle_benefit_package
             off_cycle_enrollment_status est_participation actions]
        )
      end
    end

    context 'when the current plan year is terminated without an off-cycle application' do
      subject(:table) { table_for(current_terminated: true) }

      it 'keeps the current-year columns, as only an off-cycle employer can be current-year terminated' do
        expect(table.current_py_terminated?).to be(false)
        expect(table.columns.map { |col| col[:name] }).to include('benefit_package', 'enrollment_status')
      end
    end
  end

  describe '#collection' do
    let!(:census_employee) do
      FactoryBot.create(:benefit_sponsors_census_employee, employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship)
    end

    it 'wraps the employer profile in the legacy employee query' do
      expect(table.collection({})).to be_a(Queries::EmployeeDatatableQuery)
    end

    it 'passes the table employer profile id through to the query' do
      expect(table.collection({}).custom_attributes[:id]).to eq(employer_profile.id)
    end

    it 'defaults to the active-only roster scope when no filter tab is active' do
      expect(table.collection({}).build_scope.selector).to eq(employer_profile.census_employees.active_alone.selector)
    end

    it 'maps each filter tab to its roster scope' do
      {
        'active_alone' => employer_profile.census_employees.active_alone,
        'active' => employer_profile.census_employees.active,
        'by_cobra' => employer_profile.census_employees.by_cobra,
        'terminated' => employer_profile.census_employees.terminated,
        'all' => employer_profile.census_employees
      }.each do |tab, scope|
        expect(table.collection(employers: tab).build_scope.selector).to eq(scope.selector)
      end
    end

    it 'returns the roster on the all tab' do
      expect(table.collection(employers: 'all').build_scope.to_a).to eq([census_employee])
    end

    it 'searches the roster by census employee name' do
      results = table.collection(employers: 'all').datatable_search(census_employee.last_name).build_scope
      expect(results.to_a).to eq([census_employee])
    end

    it 'excludes a roster the search does not match' do
      results = table.collection(employers: 'all').datatable_search('zzzznomatch').build_scope
      expect(results.to_a).to be_empty
    end
  end

  describe 'filter definition' do
    it 'offers the legacy roster status tabs in order' do
      expect(table.filters[:employers].map { |tab| tab[:scope] }).to eq(%w[active_alone active by_cobra terminated all])
      expect(table.filters[:employers].map { |tab| tab[:label] }).to eq(
        ['Active only', 'Active & COBRA', 'COBRA only', 'Terminated', 'All']
      )
      expect(table.filters[:top_scope]).to eq(:employers)
    end

    it 'collects only the roster status tab into the collection attributes' do
      expect(table.filter_scopes).to eq([:employers])
    end
  end

  describe '#bulk_actions' do
    it 'offers the three expected-selection actions, each posting its own selection' do
      expect(table.bulk_actions.map { |action| action[:label] }).to eq(
        ['Employee will enroll', 'Employee will not enroll with valid waiver', 'Employee will not enroll with invalid waiver']
      )
      expect(table.bulk_actions.map { |action| action[:url] }).to all(include('census_employees/change_expected_selection'))
      expect(table.bulk_actions.map { |action| action[:url][/expected_selection=(\w+)/, 1] }).to eq(
        %w[enroll waive will_not_participate]
      )
    end

    it 'carries the legacy confirmation text' do
      expect(table.bulk_actions.first[:confirm]).to eq(
        'These employees will be used to estimate your group size and participation rate'
      )
    end
  end

  describe 'chrome configuration' do
    it 'renders no export buttons: the tab hid them and its roster CSV is a separate download' do
      expect(table.buttons).to eq([])
    end

    it 'uses the standard grid arrangement and page length menu' do
      expect(table.layout).to eq(Datatables::Layouts::STANDARD)
      expect(table.per_page_options).to eq([10, 25, 50, 100])
    end

    it 'keeps page-global selectric and numbers columns from zero' do
      expect(table.disable_selectric?).to be(false)
      expect(table.column_index_offset).to eq(0)
    end

    it 'renders the search box' do
      expect(table.global_search?).to be(true)
    end

    it 'has no date filter' do
      expect(table.date_filter).to be_nil
    end
  end
end
