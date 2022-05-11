# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe PersistEnrollmentAndAssignToAssignments, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'when invalid params are passed ' do
    it 'when employee_role is not passed' do
      context = described_class.call(employee_role: nil, shopping_enrollments: [hbx_enrollment])
      expect(context.success?).to eq true
    end

    it 'when hbx_enrollment is not passed' do
      context = described_class.call(employee_role: employee_role, shopping_enrollments: [])
      expect(context.success?).to eq true
    end
  end

  context 'when valid params are passed' do
    it 'when enr is saved' do
      described_class.call(employee_role: employee_role, shopping_enrollments: [hbx_enrollment])
      assignment = ce.benefit_group_assignment_by_package(hbx_enrollment.sponsored_benefit_package_id, hbx_enrollment.effective_on)
      assignment.reload
      expect(assignment.hbx_enrollment_id).to eq hbx_enrollment.id
      expect(hbx_enrollment.benefit_group_assignment_id).to eq assignment.id
    end

    it 'when enr cannot be saved' do
      allow(hbx_enrollment).to receive(:save).and_return(false)
      context = described_class.call(employee_role: employee_role, shopping_enrollments: [hbx_enrollment])
      expect(context.failure?).to eq true
      expect(context.message).to eq 'failed to save enrollment'
    end
  end
end