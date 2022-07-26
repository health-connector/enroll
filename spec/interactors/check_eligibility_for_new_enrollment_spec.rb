# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe CheckEligibilityForNewEnrollment, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'CheckEligibilityForNewEnrollment' do
    it 'when ce is not passed' do
      context = described_class.call(census_employee: nil, params: {is_waiving: true, family_member_ids: []})
      expect(context.success?).to eq true
    end

    it 'when ce passed' do
      allow(census_employee).to receive(:new_hire_enrollment_period).and_return(((TimeKeeper.date_of_record + 1.day)..(TimeKeeper.date_of_record + 10.day)))
      context = described_class.call(census_employee: census_employee, params: {is_waiving: true, family_member_ids: []})
      expect(context.failure?).to eq true
      expect(context.message).to eq "You're not yet eligible under your employer-sponsored benefits. Please return on #{census_employee.new_hire_enrollment_period.begin.strftime('%m/%d/%Y')} to enroll for coverage."
    end

    it 'when is_waiving is not blank' do
      allow(census_employee).to receive(:new_hire_enrollment_period).and_return(((TimeKeeper.date_of_record - 1.day)..(TimeKeeper.date_of_record + 10.day)))
      context = described_class.call(census_employee: census_employee, params: {is_waiving: true, family_member_ids: []})
      expect(context.success?).to eq true
    end

    it 'when is_waiving is blank and family members are nil' do
      allow(census_employee).to receive(:new_hire_enrollment_period).and_return(((TimeKeeper.date_of_record - 1.day)..(TimeKeeper.date_of_record + 10.day)))
      context = described_class.call(census_employee: census_employee, params: {is_waiving: nil, family_member_ids: []})
      expect(context.failure?).to eq true
      expect(context.message).to eq 'You must select at least one Eligible applicant to enroll in the healthcare plan'
    end
  end
end