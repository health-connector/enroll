# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe AssignShopAttributesToEnrollments, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'invalid params' do
    it 'when market and hbx_enrollment is not passed' do
      described_class.call(market_kind: nil, shopping_enrollments: [], params: {commit: nil})
      expect(hbx_enrollment.enrollment_signature).to eq nil
      expect(hbx_enrollment.special_enrollment_period_id).to eq nil
      expect(hbx_enrollment.original_application_type).to eq nil
    end

    it 'when market is not passed' do
      described_class.call(market_kind: nil, shopping_enrollments: [hbx_enrollment], params: {commit: nil})
      expect(hbx_enrollment.enrollment_signature).not_to eq nil
    end
  end

  context 'when valid params are passed' do
    context 'sending all valid params' do
      before :each do
        family.special_enrollment_periods << sep
        described_class.call(market_kind: 'shop', shopping_enrollments: [hbx_enrollment],
                             employee_role: employee_role,
                             session_original_application_type: 'string',
                             params: {commit: 'Keep existing plan'})
      end

      it 'should set enrollment_signature' do
        expect(hbx_enrollment.enrollment_signature).not_to eq nil
      end

      it 'should set special_enrollment_period_id' do
        expect(hbx_enrollment.special_enrollment_period_id).to eq sep.id
      end

      it 'should set original_application_type' do
        expect(hbx_enrollment.original_application_type).to eq 'string'
      end
    end

    context 'when employee is cobra' do
      before :each do
        allow(employee_role).to receive(:is_cobra_status?).and_return(true)
        ce.update_attributes(cobra_begin_date: hbx_enrollment.effective_on + 10.days)
        described_class.call(market_kind: 'shop', shopping_enrollments: [hbx_enrollment],
                             employee_role: employee_role,
                             params: {commit: 'Keep existing plan'})
      end

      it 'should set kind' do
        expect(hbx_enrollment.kind).to eq 'employer_sponsored_cobra'
      end

      it 'should set effective_on' do
        expect(hbx_enrollment.effective_on).to eq(ce.cobra_begin_date)
      end
    end
  end
end