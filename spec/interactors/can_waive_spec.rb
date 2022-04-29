# frozen_string_literal: true

require "rails_helper"
require './spec//shared_context/setup_shop_families_enrollments'

describe CanWaive, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'should not assign waivable' do
    it 'when hbx_enrollment and market are not passed' do
      context = described_class.call(previous_hbx_enrollment: nil, market_kind: nil)
      expect(context.waivable).to eq nil
    end
  end

  context 'should assign waivable' do
    it 'when shop enrollment is passed and market kind is true' do
      context = described_class.call(previous_hbx_enrollment: hbx_enrollment, market_kind: nil)
      expect(context.waivable).to eq true
    end

    it 'when ivl enrollment is passed and market kind is false' do
      hbx_enrollment.update_attributes(kind: 'individual')
      context = described_class.call(previous_hbx_enrollment: hbx_enrollment, market_kind: nil)
      expect(context.waivable).to eq false
    end

    it 'when enrollment is not passed and market kind is shop' do
      context = described_class.call(previous_hbx_enrollment: nil, market_kind: 'shop')
      expect(context.waivable).to eq true
    end

    it 'when enrollment is not passed and market kind is ivl' do
      context = described_class.call(previous_hbx_enrollment: nil, market_kind: 'individual')
      expect(context.waivable).to eq false
    end
  end
end