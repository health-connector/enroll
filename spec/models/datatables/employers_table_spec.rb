# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Datatables::EmployersTable, dbclean: :after_each do
  subject(:table) { described_class.new }

  describe '#columns' do
    context 'when employer attestations are enabled' do
      before { allow(table).to receive(:employer_attestation_is_enabled?).and_return(true) }

      it 'mirrors the legacy column order and labels, including the attestation column' do
        expect(table.columns.map { |col| col[:name] }).to eq(
          %w[bulk_actions legal_name fein hbx_id broker source_kind plan_year_state effective_date invoiced? attestation_status actions]
        )
        expect(table.columns.map { |col| col[:label] }).to eq(
          ['', 'Legal Name', 'FEIN', 'HBX ID', 'Broker', 'Source Kind', 'Plan Year State', 'Effective Date', 'Invoiced?', 'Attestation Status', 'Actions']
        )
      end
    end

    context 'when employer attestations are disabled' do
      before { allow(table).to receive(:employer_attestation_is_enabled?).and_return(false) }

      it 'drops the attestation_status column' do
        expect(table.columns.map { |col| col[:name] }).not_to include('attestation_status')
      end
    end

    it 'marks only effective_date sortable, matching the legacy flags' do
      expect(table.columns.select { |col| col[:sortable] }.map { |col| col[:name] }).to eq(%w[effective_date])
    end

    it 'declares the source_kind select filter (the app\'s only per-column filter)' do
      source_kind = table.columns.find { |col| col[:name] == 'source_kind' }
      expect(source_kind[:filter][:selected]).to eq('all')
      expect(source_kind[:filter][:collection]).to eq([:all] + BenefitSponsors::BenefitSponsorships::BenefitSponsorship::SOURCE_KINDS)
    end

    it 'flags the bulk_actions column header so the check-all box renders' do
      expect(table.columns.first).to include(name: 'bulk_actions', type: :bulk_actions_column, header: :bulk_all)
    end
  end

  describe '#default_order_column' do
    it 'orders by the hidden created_at column, so no visible header is the active sort' do
      expect(table.default_order_column).to eq('created_at')
    end
  end

  describe '#column_index_offset' do
    it 'offsets by one for the hidden leading created_at column' do
      expect(table.column_index_offset).to eq(1)
    end
  end

  describe '#collection' do
    it 'narrows BenefitSponsorship by the active employers tab scope through the whitelist' do
      criteria = table.collection(employers: 'benefit_sponsorship_applicant')
      expect(criteria.selector['aasm_state']).to eq(:applicant)
    end

    it 'ignores a filter value that is not on the whitelist (injection guard)' do
      criteria = table.collection(employers: 'destroy_all')
      expect(criteria.selector).to eq(BenefitSponsors::BenefitSponsorships::BenefitSponsorship.unscoped.selector)
    end

    it 'returns the unscoped collection for the All tab' do
      criteria = table.collection(employers: 'all')
      expect(criteria.selector).to eq(BenefitSponsors::BenefitSponsorships::BenefitSponsorship.unscoped.selector)
    end
  end

  describe '#search_column' do
    let(:collection) { double('collection') }

    it 'applies the source_kind filter for a concrete value' do
      expect(collection).to receive(:datatable_search_for_source_kind).with(:conversion).and_return(:filtered)
      expect(table.search_column(collection, 'source_kind', 'conversion')).to eq(:filtered)
    end

    it 'is a no-op for the "all" value' do
      expect(collection).not_to receive(:datatable_search_for_source_kind)
      expect(table.search_column(collection, 'source_kind', 'all')).to eq(collection)
    end

    it 'is a no-op for any other column' do
      expect(table.search_column(collection, 'legal_name', 'conversion')).to eq(collection)
    end
  end

  describe '#bulk_actions' do
    it 'declares Generate Invoice and Mark Binder Paid against their existing endpoints' do
      labels = table.bulk_actions.map { |action| action[:label] }
      expect(labels).to eq(['Generate Invoice', 'Mark Binder Paid'])
      expect(table.bulk_actions.first[:url]).to eq('/exchanges/hbx_profiles/generate_invoice')
      expect(table.bulk_actions.last[:url]).to eq('/exchanges/hbx_profiles/binder_paid')
    end
  end

  describe 'csv export' do
    before { allow(table).to receive(:employer_attestation_is_enabled?).and_return(false) }

    it 'excludes the bulk-actions and actions columns from the headers' do
      expect(table.csv_headers).to eq(
        ['Legal Name', 'FEIN', 'HBX ID', 'Broker', 'Source Kind', 'Plan Year State', 'Effective Date', 'Invoiced?']
      )
    end

    it 'renders plain-text cell values for one row' do
      organization = double('organization', legal_name: 'Acme Co', fein: '223456789', hbx_id: '12345')
      employer_profile = double('employer_profile', active_broker_agency_legal_name: 'Best Brokers', current_month_invoice: nil)
      benefit_application = double('benefit_application', effective_period: (Date.new(2026, 1, 1)..Date.new(2026, 12, 31)))
      row = double('benefit_sponsorship', organization: organization, source_kind: :self_serve, dt_display_benefit_application: benefit_application)
      allow(organization).to receive(:employer_profile).and_return(employer_profile)
      allow(table).to receive(:helpers).and_return(double(benefit_application_summarized_state: 'Enrolling'))

      expect(table.csv_row(row)).to eq(
        ['Acme Co', '223456789', '12345', 'Best Brokers', 'Self serve', 'Enrolling', '01/01/2026', false]
      )
    end
  end
end
