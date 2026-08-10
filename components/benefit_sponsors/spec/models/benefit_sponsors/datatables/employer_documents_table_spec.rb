# frozen_string_literal: true

require 'rails_helper'

module BenefitSponsors
  RSpec.describe Datatables::EmployerDocumentsTable, dbclean: :after_each do
    let!(:site) { FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    let!(:organization) do
      FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site)
    end
    let(:employer_profile) { organization.employer_profile }
    let(:attestation) { FactoryBot.create(:employer_attestation, aasm_state: 'submitted') }
    let!(:document) { FactoryBot.create(:employer_attestation_document, employer_attestation: attestation) }

    subject(:table) { described_class.new(employer_profile) }

    before { allow(employer_profile).to receive(:employer_attestation).and_return(attestation) }

    describe '#columns' do
      it 'mirrors the legacy BenefitSponsorsEmployerDocumentsDataTable column order and labels' do
        expect(table.columns.map { |col| col[:name] }).to eq(['Doc Status', 'name', 'type', 'size', 'date', 'actions'])
        expect(table.columns.map { |col| col[:label] }).to eq(
          ['Doc Status', 'Doc Name', 'Doc Type', 'Size', 'Submitted At', 'Actions']
        )
      end

      it 'keeps the first column name as the literal "Doc Status", space included' do
        expect(table.columns.first[:name]).to eq('Doc Status')
      end

      it 'marks no column sortable and flags the first as pre-ordered' do
        expect(table.columns.none? { |col| col[:sortable] }).to be(true)
        expect(table.columns.select { |col| col[:ordered] }.map { |col| col[:name] }).to eq(['Doc Status'])
        expect(table.default_order_column).to eq('Doc Status')
      end

      it 'types every column as a string' do
        expect(table.columns.map { |col| col[:type] }.uniq).to eq([:string])
      end
    end

    describe '#collection' do
      it 'returns the attestation documents' do
        expect(table.collection({}).to_a).to eq([document])
      end

      it 'returns an empty set when the employer has no attestation' do
        allow(employer_profile).to receive(:employer_attestation).and_return(nil)
        expect(table.collection({}).to_a).to be_empty
      end
    end

    describe '#delete_link_type' do
      it 'enables delete while the attestation is editable and the document submitted' do
        allow(attestation).to receive(:editable?).and_return(true)
        allow(document).to receive(:submitted?).and_return(true)
        expect(table.delete_link_type(document)).to eq('delete ajax with confirm')
      end

      it 'disables delete once the attestation is no longer editable' do
        allow(attestation).to receive(:editable?).and_return(false)
        allow(document).to receive(:submitted?).and_return(true)
        expect(table.delete_link_type(document)).to eq('disabled')
      end

      it 'disables delete for a document that is not submitted' do
        allow(attestation).to receive(:editable?).and_return(true)
        allow(document).to receive(:submitted?).and_return(false)
        expect(table.delete_link_type(document)).to eq('disabled')
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

      it 'renders no export buttons: the tab hid them' do
        expect(table.buttons).to eq([])
      end

      it 'renders no bulk actions' do
        expect(table.bulk_actions).to eq([])
      end

      it 'uses the standard grid arrangement and page length menu' do
        expect(table.layout).to eq(::Datatables::Layouts::STANDARD)
        expect(table.per_page_options).to eq([10, 25, 50, 100])
      end
    end
  end
end
