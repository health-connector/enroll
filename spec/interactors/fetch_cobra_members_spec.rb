# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe FetchCobraMembers, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'should not assign context' do
    it 'should return success' do
      context = described_class.call(market_kind: nil)
      expect(context.success?).to eq true
    end

    it 'should return success' do
      context = described_class.call(market_kind: 'shop', change_plan: nil)
      expect(context.success?).to eq true
    end

    it 'should return success' do
      context = described_class.call(market_kind: 'shop', change_plan: 'change_by_qle')
      expect(context.success?).to eq true
    end

    it 'should return success' do
      context = described_class.call(market_kind: 'shop', employee_role: employee_role)
      expect(context.success?).to eq true
    end
  end

  context 'should assign context' do
    before :each do
      allow(employee_role).to receive(:is_cobra_status?).and_return(true)
    end

    it 'when family is not passed' do
      context = described_class.call(market_kind: 'shop', employee_role: employee_role)
      expect(context.coverage_family_members_for_cobra).to eq nil
    end

    it 'when enr is not shopping' do
      context = described_class.call(market_kind: 'shop', employee_role: employee_role, primary_family: family)
      expect(context.coverage_family_members_for_cobra).to eq nil
    end

    it 'when valid params are passed.' do
      hbx_enrollment.update_attributes(aasm_state: 'coverage_selected')
      context = described_class.call(market_kind: 'shop', employee_role: employee_role, primary_family: family)
      expect(context.coverage_family_members_for_cobra).not_to eq nil
    end
  end
end