# frozen_string_literal: true

require "rails_helper"

describe AssignCommonParamsForMemberSelection, :dbclean => :after_each do
  context 'should assign attributes' do
    let(:params) do
      {change_plan: 'change_by_qle', shop_under_current: 'true', shop_under_future: 'false',
       enrollment_kind: 'sep',
       effective_on_option_selected: '2022-04-25',
       commit: 'shop_for_plans'}
    end

    before do
      @context = described_class.call(params: params)
    end

    it 'should assign change_plan' do
      expect(@context.change_plan).to eq 'change_by_qle'
    end

    it 'should assign shop_under_current' do
      expect(@context.shop_under_current).to eq true
    end

    it 'should assign shop_under_future' do
      expect(@context.shop_under_future).to eq false
    end

    it 'should assign coverage_kind' do
      expect(@context.coverage_kind).to eq 'health'
    end

    it 'should assign enrollment_kind' do
      expect(@context.enrollment_kind).to eq 'sep'
    end

    it 'should not assign shop_for_plans' do
      expect(@context.shop_for_plans).to eq ''
    end

    it 'should assign optional_effective_on' do
      expect(@context.optional_effective_on).to eq Date.new(2022, 0o4, 25)
    end

    it 'should not assign qle' do
      expect(@context.qle).to eq true
    end

    it 'should not assign commit' do
      expect(@context.commit).to eq 'shop_for_plans'
    end
  end

  context 'optional_effective_on parsing' do
    it 'parses ISO formatted date strings via Date.parse' do
      context_obj = described_class.call(params: { effective_on_option_selected: '2025-01-05' })
      expect(context_obj.optional_effective_on).to eq Date.new(2025, 1, 5)
    end

    it 'is nil when effective_on_option_selected is not provided' do
      context_obj = described_class.call(params: {})
      expect(context_obj.optional_effective_on).to be_nil
    end
  end
end