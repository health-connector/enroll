# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe ExtractContinuousShoppingParams, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'ExtractContinuousShoppingParams' do
    it 'when hbx_enrollment id is not passed' do
      context = described_class.call(cart: {:health => {:id => nil}})
      expect(context.failure?).to eq true
      expect(context.message).to eq "missing cart enrollment id"
    end

    it 'when hbx_enrollment invalid id is passed' do
      context = described_class.call(cart: {:health => {:id => '12344'}})
      expect(context.success?).to eq true
      expect(context.employee_role_id).to eq nil
      expect(context.person_id).to eq nil
      expect(context.market_kind).to eq nil
      expect(context.enrollment_kind).to eq nil
      expect(context.new_effective_on).to eq nil
    end

    it 'when hbx_enrollment id is passed' do
      context = described_class.call(cart: {:health => {:id => hbx_enrollment.id}})
      expect(context.success?).to eq true
      expect(context.employee_role_id).to eq employee_role.id
      expect(context.person_id).to eq ee_person.id
      expect(context.market_kind).to eq 'shop'
      expect(context.enrollment_kind).to eq hbx_enrollment.enrollment_kind
      expect(context.new_effective_on).to eq hbx_enrollment.effective_on
    end
  end
end