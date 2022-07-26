# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe DisableMarketKinds, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'when passed with invalid params' do
    it 'when disable_market_kind should be nil' do
      context = described_class.call(change_plan: nil, enrollment_kind: nil)
      expect(context.success?).to eq true
      expect(context.disable_market_kind).to eq nil
    end

    it 'disable_market_kind should be shop' do
      context = described_class.call(change_plan: 'change_by_qle', person: nil, params: {qle_id: nil})
      expect(context.success?).to eq true
      expect(context.disable_market_kind).to eq 'shop'
    end
  end

  context 'when passed with valid params' do
    it 'disable_market_kind should be ivl' do
      context = described_class.call(change_plan: 'change_by_qle', person: ee_person, params: {market_kind: nil})
      expect(context.success?).to eq true
      expect(context.disable_market_kind).to eq 'individual'
    end

    it 'disable_market_kind should ivl' do
      context = described_class.call(change_plan: 'change_by_qle', person: ee_person, params: {market_kind: 'shop'})
      expect(context.success?).to eq true
      expect(context.disable_market_kind).to eq 'individual'
    end

    it 'disable_market_kind should be ivl' do
      allow(ee_person).to receive(:has_active_resident_role?).and_return(false)
      context = described_class.call(change_plan: 'change_by_qle', person: ee_person, params: {qle_id: qle_kind.id})
      expect(context.success?).to eq true
      expect(context.disable_market_kind).to eq 'individual'
    end

    it 'disable_market_kind should be ivl' do
      context = described_class.call(change_plan: 'change_by_qle', person: ee_person, params: {qle_id: nil})
      expect(context.success?).to eq true
      expect(context.disable_market_kind).to eq 'individual'
    end

    it 'disable_market_kind should be shop' do
      allow(ee_person).to receive(:has_active_employee_role?).and_return(false)
      allow(ee_person).to receive(:has_active_consumer_role?).and_return(true)
      allow(ee_person).to receive(:has_active_resident_role?).and_return(false)
      context = described_class.call(change_plan: 'change_by_qle', person: ee_person, params: {market_kind: nil, qle_id: nil})
      expect(context.success?).to eq true
      expect(context.disable_market_kind).to eq 'shop'
    end

    it 'disable_market_kind should be shop' do
      allow(ee_person).to receive(:has_active_employee_role?).and_return(false)
      allow(ee_person).to receive(:has_active_resident_role?).and_return(true)
      context = described_class.call(change_plan: 'change_by_qle', person: ee_person, params: {market_kind: nil, qle_id: nil})
      expect(context.success?).to eq true
      expect(context.disable_market_kind).to eq 'shop'
    end
  end
end