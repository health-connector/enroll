# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Eligible::Eligibility, type: :model do
  subject do
    described_class.new(
      key: :test_key,
      title: 'Eligibility Test',
      description: 'This is a test eligibility'
    )
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_uniqueness_of(:key) }
  end

  describe '#eligible?' do
    it 'returns true when current_state is eligible' do
      subject.current_state = :eligible
      expect(subject.eligible?).to be true
    end

    it 'returns false when current_state is not eligible' do
      subject.current_state = :ineligible
      expect(subject.eligible?).to be false
    end
  end

  describe '#latest_state_history' do
    let!(:state_history1) { subject.state_histories.build(created_at: 1.day.ago) }
    let!(:state_history2) { subject.state_histories.build(created_at: 2.days.ago) }

    it 'returns the state history with the latest created_at timestamp' do
      expect(subject.latest_state_history).to eq(state_history1)
    end
  end

  describe '.register' do
    it 'registers a resource reference in the resource_ref_dir' do
      described_class.register(:grant, :test_grant, class_name: 'TestGrant', optional: true, meta: {})
      expect(described_class.resource_ref_dir[:grants][:test_grant].class_name).to eq('TestGrant')
    end
  end

  describe '.create_objects' do
    let(:collection) { [OpenStruct.new(key: :test_key)] }
    let(:type) { 'grants' }

    it 'creates objects based on the given collection and type' do
      allow(described_class).to receive(:grants_resource_for).and_return('Eligible::Grant')
      expect(described_class.create_objects(collection, type)).to all(be_an(Eligible::Grant))
    end
  end
end
