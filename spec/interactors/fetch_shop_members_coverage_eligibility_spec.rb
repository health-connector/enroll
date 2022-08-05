# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe FetchShopMembersCoverageEligibility, :dbclean => :after_each do
  include_context "setup shop families enrollments"
  let(:family_members) {hbx_enrollment.hbx_enrollment_members.map(&:family_members)}
  let(:benefit_package) {hbx_enrollment.sponsored_benefit_package}

  context 'should not set context' do
    it 'when benefit_package is not passed' do
      context = described_class.call(benefit_package: nil)
      expect(context.failure?).to eq true
      expect(context.message).to eq "no benefit_package"
    end

    it 'when family_members is not passed' do
      context = described_class.call(benefit_package: benefit_package, family_members: nil, new_effective_on: hbx_enrollment.effective_on)
      expect(context.success?).to eq true
    end

    it 'when new_effective_on is not passed' do
      context = described_class.call(benefit_package: benefit_package, family_members: family_members, new_effective_on: nil)
      expect(context.success?).to eq true
    end
  end

  context 'when valid params are passed' do
    it 'should set context values' do
      context = described_class.call(benefit_package: benefit_package, family_members: family_members, new_effective_on: hbx_enrollment.effective_on)
      expect(context.success?).to eq true
      expect(context.coverage_eligibility).not_to eq nil
    end
  end
end