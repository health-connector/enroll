# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe BuildJsonPayloadForShopping, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'not passing hbx_enrollment' do
    before :each do
      @context = described_class.call(shopping_enrollments: [],
                                      params: {cart: nil, event: nil},
                                      enrollment_kind: hbx_enrollment.enrollment_kind,
                                      change_plan: 'change_by_qle')
    end

    it 'should return error message when there are no hopping enrollments' do
      expect(@context[:message]).to eq("In order to continue, at least one member must be selected to enroll in coverage.")
    end
  end

  context 'passing valid' do
    before :each do
      @context = described_class.call(shopping_enrollments: [hbx_enrollment],
                                      params: {cart: nil, event: nil},
                                      enrollment_kind: hbx_enrollment.enrollment_kind,
                                      change_plan: 'change_by_qle')
    end

    it 'should return plan_selection_json' do
      expect(@context.plan_selection_json[:health]).to eq({:enrollment_id => hbx_enrollment.id,
                                                           :market_kind => hbx_enrollment.kind,
                                                           :enrollment_kind => hbx_enrollment.enrollment_kind,
                                                           :change_plan => 'change_by_qle'})
    end

    it 'should health_offering' do
      expect(@context.plan_selection_json[:health_offering]).to eq true
    end

    it 'should dental_offering' do
      expect(@context.plan_selection_json[:dental_offering]).to eq false
    end
  end
end