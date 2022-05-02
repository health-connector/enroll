# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe CalculateNewEffectiveOn, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'should not assign new_effective_on' do
    it 'when market_kind is not passed' do
      context = described_class.call(market_kind: nil)
      expect(context.failure?).to eq true
      expect(context.message).to eq 'missing market_kind'
    end

    it 'when family is not passed' do
      context = described_class.call(market_kind: "individual", primary_family: nil)
      expect(context.new_effective_on).to eq nil
    end

    it 'when market is shop and family is nil' do
      context = described_class.call(market_kind: "shop", primary_family: nil)
      expect(context.new_effective_on).to eq nil
    end
  end

  context 'should assign new_effective_on' do
    it 'should set new_effective_on' do
      context = described_class.call(market_kind: 'shop', primary_family: family, employee_role: employee_role, benefit_package: hbx_enrollment.sponsored_benefit_package)
      expect(context.new_effective_on.class).to eq Time
    end
  end
end