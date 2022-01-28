# frozen_string_literal: true

require 'rails_helper'

describe 'broker_agencies/quotes/_plan_comparison_export.html.erb', dbclean: :after_each do

  let(:qhp) do
    double(
      'Qhp',
      plan: plan
    )
  end

  let(:plan) do
    double(
      'Plan',
      issuer_profile: issuer_profile,
      hios_id: '12345678912-01',
      name: 'MyName',
      plan_type: 'PPO',
      metal_level: 'Silver',
      kind: 'shop',
      active_year: TimeKeeper.date_of_record.year,
      metal_level_kind: 'dental',
      dental_level: 'dental',
      network_information: 'NetworkInformation',
      provider_directory_url: 'provider_directory_url',
      rx_formulary_url: 'rx_formulary_url',
      coverage_kind: 'health',
      sbc_document: sbc_document
    )
  end

  let(:sbc_document) do
    double(
      'SbcDocument',
      identifier: 'identifier'
    )
  end

  let(:issuer_profile) do
    double(
      'IssuerProfile',
      legal_name: 'Carrier Legal Name'
    )
  end

  context 'when exported' do
    before do
      assign(:visit_types, [])
      render partial: 'broker_agencies/quotes/plan_comparison_export', locals: { qhps: [qhp] }
    end

    it 'should have proper sbc link text for health and dental plans' do
      expect(rendered).to have_selector('a', text: 'Summary of Benefits and Coverage')
    end
  end
end
