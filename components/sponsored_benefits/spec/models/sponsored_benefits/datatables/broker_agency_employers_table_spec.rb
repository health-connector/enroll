# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SponsoredBenefits::Datatables::BrokerAgencyEmployersTable, type: :model do
  let(:broker_agency_profile) { double(:broker_agency_profile, id: BSON::ObjectId.new) }

  subject(:table) { described_class.new(broker_agency_profile) }

  describe '#columns' do
    it 'mirrors the legacy BrokerAgencyEmployerDatatable column order and labels' do
      expect(table.columns.map { |col| col[:name] }).to eq(
        %w[legal_name fein ee_count er_state effective_date broker actions]
      )
      expect(table.columns.map { |col| col[:label] }).to eq(
        ['Legal Name', 'FEIN', 'EE Count', 'ER State', 'Effective Date', 'Broker', 'Actions']
      )
    end

    it 'marks no column sortable and flags legal_name as pre-ordered' do
      expect(table.columns.none? { |col| col[:sortable] }).to be(true)
      expect(table.columns.select { |col| col[:ordered] }.map { |col| col[:name] }).to eq(['legal_name'])
      expect(table.default_order_column).to eq('legal_name')
    end

    it 'gives the actions column the legacy width' do
      expect(table.columns.last[:width]).to eq('50px')
    end

    context 'when the individual market is disabled' do
      before { allow(table).to receive(:individual_market_is_enabled?).and_return(false) }

      it 'renders no checkbox column' do
        expect(table.show_bulk_actions_column?).to be(false)
        expect(table.columns.map { |col| col[:type] }).not_to include(:bulk_actions_column)
        expect(table.columns.first[:name]).to eq('legal_name')
      end
    end

    context 'when the individual market is enabled' do
      before { allow(table).to receive(:individual_market_is_enabled?).and_return(true) }

      it 'prepends the checkbox column' do
        expect(table.show_bulk_actions_column?).to be(true)
        expect(table.columns.first).to include(name: 'bulk_actions', type: :bulk_actions_column, header: :bulk_all)
      end

      it 'still offers no bulk action, because the legacy dropdown was empty' do
        expect(table.bulk_actions).to eq([])
      end
    end
  end

  describe '#collection' do
    it 'passes the filter attributes and the route profile to the query wrapper' do
      expect(Queries::PlanDesignOrganizationQuery).to receive(:new).with(
        { sponsors: 'active_sponsors', profile_id: broker_agency_profile.id }
      )
      table.collection(sponsors: 'active_sponsors')
    end

    it 'always scopes to the route profile, ignoring any supplied profile_id' do
      expect(Queries::PlanDesignOrganizationQuery).to receive(:new).with(
        { profile_id: broker_agency_profile.id }
      )
      table.collection(profile_id: BSON::ObjectId.new)
    end
  end

  describe '#filters' do
    it 'maps the four sponsor tabs to the query wrapper scopes' do
      expect(table.filters[:top_scope]).to eq(:sponsors)
      expect(table.filters[:sponsors].map { |tab| tab[:scope] }).to eq(
        %w[all active_sponsors inactive_sponsors prospect_sponsors]
      )
      expect(table.filters[:sponsors].map { |tab| tab[:label] }).to eq(%w[All Active Inactive Prospects])
      expect(table.filter_scopes).to eq([:sponsors])
    end
  end

  describe 'row cell values' do
    let(:benefit_application) { double(:benefit_application) }
    let(:benefit_sponsorship) { double(:benefit_sponsorship, dt_display_benefit_application: benefit_application) }
    let(:organization) { double(:organization, active_benefit_sponsorship: benefit_sponsorship) }
    let(:employer_profile) { double(:employer_profile, organization: organization, roster_size: 12) }
    let(:plan_design_organization) do
      double(:plan_design_organization, is_prospect?: false, broker_relationship_inactive?: false,
                                        employer_profile: employer_profile, fein: '123456789')
    end

    describe '#fein and #employee_count' do
      it 'returns the values for an active client' do
        expect(table.fein(plan_design_organization)).to eq('123456789')
        expect(table.employee_count(plan_design_organization)).to eq(12)
      end

      it 'returns N/A for a prospect' do
        allow(plan_design_organization).to receive(:is_prospect?).and_return(true)
        expect(table.fein(plan_design_organization)).to eq('N/A')
        expect(table.employee_count(plan_design_organization)).to eq('N/A')
      end

      it 'returns N/A for a former client' do
        allow(plan_design_organization).to receive(:broker_relationship_inactive?).and_return(true)
        expect(table.fein(plan_design_organization)).to eq('N/A')
        expect(table.employee_count(plan_design_organization)).to eq('N/A')
      end
    end

    describe '#employer_state' do
      it 'returns N/A for a prospect' do
        allow(plan_design_organization).to receive(:is_prospect?).and_return(true)
        expect(table.employer_state(plan_design_organization)).to eq('N/A')
      end

      it 'returns Former Client for an inactive broker relationship' do
        allow(plan_design_organization).to receive(:broker_relationship_inactive?).and_return(true)
        expect(table.employer_state(plan_design_organization)).to eq('Former Client')
      end

      it 'returns nil when the sponsorship has no displayable application' do
        allow(benefit_sponsorship).to receive(:dt_display_benefit_application).and_return(nil)
        expect(table.employer_state(plan_design_organization)).to be_nil
      end

      context 'with no predecessor application' do
        before { allow(benefit_application).to receive(:predecessor_id).and_return(nil) }

        {
          draft: 'Draft',
          enrollment_open: 'Enrolling',
          enrollment_eligible: 'Enrolled',
          binder_paid: 'Enrolled',
          approved: 'Published',
          pending: 'Publish Pending'
        }.each do |state, label|
          it "labels #{state} as #{label}" do
            allow(benefit_application).to receive(:aasm_state).and_return(state)
            expect(table.employer_state(plan_design_organization)).to eq(label)
          end
        end

        it 'falls back to the humanized state for an unmapped state' do
          allow(benefit_application).to receive(:aasm_state).and_return(:active)
          expect(table.employer_state(plan_design_organization)).to eq('Active')
        end
      end

      context 'with a predecessor application' do
        before { allow(benefit_application).to receive(:predecessor_id).and_return(BSON::ObjectId.new) }

        it 'prefixes the state with Renewing' do
          allow(benefit_application).to receive(:aasm_state).and_return(:enrollment_open)
          expect(table.employer_state(plan_design_organization)).to eq('Renewing Enrolling')
        end

        it 'drops the prefix once the application is active' do
          allow(benefit_application).to receive(:aasm_state).and_return(:active)
          expect(table.employer_state(plan_design_organization)).to eq('Active')
        end
      end
    end

    describe '#effective_date' do
      it 'formats the latest plan year start' do
        allow(employer_profile).to receive(:latest_plan_year).and_return(double(start_on: Date.new(2026, 3, 1)))
        expect(table.effective_date(plan_design_organization)).to eq('03/01/2026')
      end

      it 'reports no active plan when there is no plan year' do
        allow(employer_profile).to receive(:latest_plan_year).and_return(nil)
        expect(table.effective_date(plan_design_organization)).to eq('No Active Plan')
      end
    end

    describe 'row action link types' do
      it 'enables edit and remove for a prospect only' do
        allow(plan_design_organization).to receive(:is_prospect?).and_return(true)
        expect(table.edit_employer_link_type(plan_design_organization)).to eq('ajax')
        expect(table.remove_employer_link_type(plan_design_organization)).to eq('delete with confirm')
      end

      it 'disables edit and remove for a real client' do
        expect(table.edit_employer_link_type(plan_design_organization)).to eq('disabled')
        expect(table.remove_employer_link_type(plan_design_organization)).to eq('disabled')
      end
    end
  end

  describe 'CSV export' do
    it 'omits the actions column from the headers' do
      expect(table.csv_headers).to eq(['Legal Name', 'FEIN', 'EE Count', 'ER State', 'Effective Date', 'Broker'])
    end

    it 'omits the checkbox column from the headers when the individual market is on' do
      allow(table).to receive(:individual_market_is_enabled?).and_return(true)
      expect(table.csv_headers).to eq(['Legal Name', 'FEIN', 'EE Count', 'ER State', 'Effective Date', 'Broker'])
    end

    it 'emits one plain-text value per exported column' do
      row = double(:plan_design_organization, legal_name: 'Peter Rabbit')
      allow(table).to receive_messages(fein: '123456789', employee_count: 12, employer_state: 'Enrolling',
                                       effective_date: '03/01/2026', broker_name: 'M D')
      expect(table.csv_row(row)).to eq(['Peter Rabbit', '123456789', 12, 'Enrolling', '03/01/2026', 'M D'])
      expect(table.csv_row(row).size).to eq(table.csv_headers.size)
    end
  end

  describe 'chrome configuration' do
    it 'renders a search box and the default export buttons' do
      expect(table.global_search?).to be(true)
      expect(table.buttons).to eq(%w[csv excel])
    end

    it 'renders no date filter' do
      expect(table.date_filter).to be_nil
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
