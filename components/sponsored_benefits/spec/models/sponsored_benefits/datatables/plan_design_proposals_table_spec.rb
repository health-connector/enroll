# frozen_string_literal: true

require 'rails_helper'

module SponsoredBenefits
  RSpec.describe Datatables::PlanDesignProposalsTable, type: :model do
    let(:plan_design_organization) { double(:plan_design_organization, id: BSON::ObjectId.new) }

    subject(:table) { described_class.new(plan_design_organization) }

    describe '#columns' do
      it 'mirrors the legacy PlanDesignProposalsDatatable column order and labels' do
        expect(table.columns.map { |col| col[:name] }).to eq(
          %w[title effective_date claim_code employees families plan_option_kind reference_plan state actions]
        )
        expect(table.columns.map { |col| col[:label] }).to eq(
          ['Quote Name', 'Effective Date', 'Claim Code', 'Employees', 'Families', 'Plan Type', 'Reference Plan', 'State', 'Actions']
        )
      end

      it 'makes effective_date the only sortable column' do
        expect(table.columns.select { |col| col[:sortable] }.map { |col| col[:name] }).to eq(['effective_date'])
      end

      it 'flags title as the pre-ordered column' do
        expect(table.columns.select { |col| col[:ordered] }.map { |col| col[:name] }).to eq(['title'])
        expect(table.default_order_column).to eq('title')
      end

      it 'types every column as a string' do
        expect(table.columns.map { |col| col[:type] }.uniq).to eq([:string])
      end
    end

    describe '#collection' do
      it 'passes the filter attributes and the route organization to the query wrapper' do
        expect(Queries::PlanDesignProposalsQuery).to receive(:new).with(
          { quotes: 'draft', organization_id: plan_design_organization.id }
        )
        table.collection(quotes: 'draft')
      end

      it 'always scopes to the route organization, ignoring any supplied organization_id' do
        expect(Queries::PlanDesignProposalsQuery).to receive(:new).with(
          { organization_id: plan_design_organization.id }
        )
        table.collection(organization_id: BSON::ObjectId.new)
      end
    end

    describe '#filters' do
      it 'maps the five quote tabs to the query wrapper scopes' do
        expect(table.filters[:top_scope]).to eq(:quotes)
        expect(table.filters[:quotes].map { |tab| tab[:scope] }).to eq(%w[all initial draft published expired])
        expect(table.filters[:quotes].map { |tab| tab[:label] }).to eq(%w[All Initial Draft Published Expired])
        expect(table.filter_scopes).to eq([:quotes])
      end
    end

    describe 'row cell values' do
      let(:benefit_group) { double(:benefit_group, plan_option_kind: 'single_carrier', reference_plan: double(name: 'Silver PPO')) }
      let(:benefit_application) { double(:benefit_application, benefit_groups: [benefit_group]) }
      let(:census_employees) { double(:census_employees, count: 7) }
      let(:sponsorship) do
        double(:benefit_sponsorship, benefit_applications: [benefit_application], census_employees: census_employees,
                                     initial_enrollment_period: (Date.new(2026, 3, 1)..Date.new(2027, 2, 28)))
      end
      let(:profile) { double(:profile, benefit_sponsorships: [sponsorship]) }
      let(:proposal) do
        double(:plan_design_proposal, profile: profile, claim_code: nil, aasm_state: 'draft',
                                      published?: false, expired?: false, claimed?: false)
      end

      it 'formats the effective date as the legacy spaced-out string' do
        expect(table.effective_date(proposal)).to eq('2026 - 03 - 01')
      end

      it 'reports an unpublished quote as having no claim code' do
        expect(table.claim_code(proposal)).to eq('Not Published')
      end

      it 'returns the claim code once one exists' do
        allow(proposal).to receive(:claim_code).and_return('ABC123')
        expect(table.claim_code(proposal)).to eq('ABC123')
      end

      it 'counts employees and the subset with dependents' do
        expect(census_employees).to receive(:where).with({ 'census_dependents.0' => { '$exists' => true } }).and_return(double(count: 2))
        expect(table.employee_count(proposal)).to eq(7)
        expect(table.family_count(proposal)).to eq(2)
      end

      it 'capitalizes the state' do
        expect(table.state(proposal)).to eq('Draft')
      end

      context 'with an assigned benefit group' do
        it 'humanizes the plan option kind and names the reference plan' do
          expect(table.plan_option_kind(proposal)).to eq('Single carrier')
          expect(table.reference_plan_name(proposal)).to eq('Silver PPO')
        end
      end

      context 'without an assigned benefit group' do
        it 'reports Unassigned when the application has no benefit groups' do
          allow(benefit_application).to receive(:benefit_groups).and_return([])
          expect(table.plan_option_kind(proposal)).to eq('Unassigned')
          expect(table.reference_plan_name(proposal)).to eq('Unassigned')
        end

        it 'reports Unassigned when there is no application at all' do
          allow(sponsorship).to receive(:benefit_applications).and_return([])
          expect(table.plan_option_kind(proposal)).to eq('Unassigned')
          expect(table.reference_plan_name(proposal)).to eq('Unassigned')
        end
      end

      describe '#edit_quote_link_type' do
        it 'stays editable while the quote is a draft' do
          expect(table.edit_quote_link_type(proposal)).to eq('static')
        end

        %i[published? expired? claimed?].each do |state|
          it "disables editing once the quote is #{state.to_s.delete('?')}" do
            allow(proposal).to receive(state).and_return(true)
            expect(table.edit_quote_link_type(proposal)).to eq('disabled')
          end
        end
      end

      describe '#view_quote_link' do
        let(:show_link) { '/sponsored_benefits/organizations/plan_design_proposals/1' }

        it 'is disabled for a draft quote, which has nothing to view' do
          expect(table.view_quote_link(proposal, show_link)).to eq(['View Published Quote', show_link, 'disabled'])
        end

        it 'names the published state' do
          allow(proposal).to receive(:published?).and_return(true)
          expect(table.view_quote_link(proposal, show_link)).to eq(['View Published Quote', show_link, 'static'])
        end

        it 'names the expired state' do
          allow(proposal).to receive(:expired?).and_return(true)
          expect(table.view_quote_link(proposal, show_link)).to eq(['View Expired Quote', show_link, 'static'])
        end

        it 'names the claimed state' do
          allow(proposal).to receive(:claimed?).and_return(true)
          expect(table.view_quote_link(proposal, show_link)).to eq(['View Claimed Quote', show_link, 'static'])
        end
      end
    end

    describe 'CSV export' do
      it 'omits the actions column from the headers' do
        expect(table.csv_headers).to eq(
          ['Quote Name', 'Effective Date', 'Claim Code', 'Employees', 'Families', 'Plan Type', 'Reference Plan', 'State']
        )
      end

      it 'emits one plain-text value per exported column' do
        row = double(:plan_design_proposal, title: 'Plan Design 2026')
        allow(table).to receive_messages(effective_date: '2026 - 03 - 01', claim_code: 'Not Published',
                                         employee_count: 3, family_count: 1, plan_option_kind: 'Unassigned',
                                         reference_plan_name: 'Unassigned', state: 'Draft')
        expect(table.csv_row(row)).to eq(
          ['Plan Design 2026', '2026 - 03 - 01', 'Not Published', 3, 1, 'Unassigned', 'Unassigned', 'Draft']
        )
        expect(table.csv_row(row).size).to eq(table.csv_headers.size)
      end
    end

    describe 'chrome configuration' do
      it 'renders a search box and the default export buttons' do
        expect(table.global_search?).to be(true)
        expect(table.buttons).to eq(%w[csv excel])
      end

      it 'renders no bulk actions and no date filter' do
        expect(table.bulk_actions).to eq([])
        expect(table.date_filter).to be_nil
      end

      it 'uses the standard grid arrangement and page length menu' do
        expect(table.layout).to eq(::Datatables::Layouts::STANDARD)
        expect(table.per_page_options).to eq([10, 25, 50, 100])
      end

      it 'leaves selectric alone and numbers columns from zero' do
        expect(table.disable_selectric?).to be(false)
        expect(table.column_index_offset).to eq(0)
      end
    end
  end
end
