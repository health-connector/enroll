# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BenefitSponsors::Validators::BenefitApplications::DownloadV2XmlContract do
  subject(:contract) { described_class.new }

  let(:valid_params) do
    {
      selected_event: 'some_event',
      employer_application_id: '123',
      employer_actions_id: '456',
      benefit_sponsorship: double('BenefitSponsorship', benefit_applications: [], hbx_id: '789', profile: double('Profile'))
    }
  end

  context 'with valid params' do
    it 'is valid' do
      result = contract.call(valid_params)
      expect(result).to be_success
    end
  end

  context 'with missing params' do
    it 'is invalid' do
      result = contract.call({})
      expect(result).to be_failure
      expect(result.errors.to_h.keys).to match_array([:selected_event, :employer_application_id, :employer_actions_id, :benefit_sponsorship])
    end
  end

  context 'with invalid benefit_sponsorship' do
    let(:invalid_sponsorship) { double('InvalidSponsorship') }

    it 'is invalid' do
      result = contract.call(valid_params.merge(benefit_sponsorship: invalid_sponsorship))
      expect(result).to be_failure
      expect(result.errors.to_h[:benefit_sponsorship]).to include(
        'must respond to benefit_applications',
        'must respond to hbx_id',
        'must respond to profile'
      )
    end
  end
end
