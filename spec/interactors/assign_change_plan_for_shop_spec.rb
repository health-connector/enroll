# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe AssignChangePlanForShop, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'should not assign change plan' do
    it 'when hbx_enrollment is not passed' do
      context = described_class.call(previous_hbx_enrollment: nil, primary_family: family)
      expect(context.change_plan).to eq nil
    end

    it 'when family is not passed' do
      context = described_class.call(previous_hbx_enrollment: hbx_enrollment, primary_family: nil)
      expect(context.change_plan).to eq nil
    end

    it 'when family does not have a shop sep' do
      context = described_class.call(previous_hbx_enrollment: hbx_enrollment, primary_family: family)
      expect(context.change_plan).to eq nil
    end
  end

  context 'should assign change plan' do
    before :each do
      family.special_enrollment_periods << sep
    end

    it 'when family does have a shop sep' do
      context = described_class.call(previous_hbx_enrollment: hbx_enrollment, primary_family: family)
      expect(context.change_plan).to eq 'change_by_qle'
    end
  end
end