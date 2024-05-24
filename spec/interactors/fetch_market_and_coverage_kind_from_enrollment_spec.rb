# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe FetchMarketAndCoverageKindFromEnrollment, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'should not assign context' do
    before :all do
      DatabaseCleaner.clean
    end

    it 'when hbx_enrollment is not passed' do
      context = described_class.call(previous_hbx_enrollment: nil, primary_family: family)
      expect(context.success?).to eq true
    end

    it 'when change_plan is not passed' do
      context = described_class.call(previous_hbx_enrollment: hbx_enrollment, change_plan: nil)
      expect(context.success?).to eq true
    end
  end

  context 'should assign context' do
    it 'should set context' do
      context = described_class.call(previous_hbx_enrollment: hbx_enrollment, change_plan: "change_plan")
      expect(context.mc_market_kind).to eq 'shop'
      expect(context.mc_coverage_kind).to eq hbx_enrollment.coverage_kind
    end
  end
end
