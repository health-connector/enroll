# frozen_string_literal: true

require "rails_helper"
require './spec//shared_context/setup_shop_families_enrollments'

describe ConstructWaiverEnrollment, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'should not assign waiver enrollment' do
    it 'when hbx_enrollment is not passed' do
      context = described_class.call(hbx_enrollment: nil)
      expect(context.success?).to eq true
    end
  end

  context 'when passed with valid params' do
    it 'when enr is not shopping enr' do
      hbx_enrollment.update_attributes(aasm_state: 'coverage_selected')
      context = described_class.call(hbx_enrollment: hbx_enrollment)
      expect(context.waiver_enrollment).not_to eq nil
      expect(context.waiver_enrollment).not_to eq hbx_enrollment
    end

    it 'when enr is shopping enr' do
      context = described_class.call(hbx_enrollment: hbx_enrollment)
      expect(context.waiver_enrollment).to eq hbx_enrollment
    end
  end
end