# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe FetchParamsForEligibleSelection, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'invalid params' do
    it 'when hbx_enrollment is not passed' do
      context = described_class.call(previous_hbx_enrollment: nil, primary_family: family)
      expect(context.failure?).to eq true
      expect(context.message).to eq "no previous enrollment present"
    end
  end

  context 'valid params' do
    it 'should set benefit package' do
      context = described_class.call(previous_hbx_enrollment: hbx_enrollment)
      expect(context.benefit_package).to eq hbx_enrollment.sponsored_benefit_package
    end
  end
end