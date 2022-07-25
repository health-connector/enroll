# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe AssignParamsForCheckout, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'should assign attributes' do
    it 'should set attributes to false when enr is not passed ' do
      context = described_class.call(hbx_enrollment: nil)
      expect(context.qle).to eq nil
      expect(context.employee_is_shopping_before_hire).to eq nil
    end

    it 'should set attributes to false' do
      context = described_class.call(hbx_enrollment: hbx_enrollment)
      expect(context.qle).to eq false
      expect(context.employee_is_shopping_before_hire).to eq false
    end

    it 'should qle to true' do
      hbx_enrollment.update_attributes(enrollment_kind: 'special_enrollment')
      context = described_class.call(hbx_enrollment: hbx_enrollment)
      expect(context.qle).to eq true
    end

    it 'should employee_is_shopping_before_hire to true' do
      census_employee.update_attributes(hired_on: TimeKeeper.date_of_record + 1.day)
      context = described_class.call(hbx_enrollment: hbx_enrollment)
      expect(context.employee_is_shopping_before_hire).to eq true
    end

    it 'should attributes to true' do
      hbx_enrollment.update_attributes(enrollment_kind: 'special_enrollment')
      census_employee.update_attributes(hired_on: TimeKeeper.date_of_record + 1.day)
      context = described_class.call(hbx_enrollment: hbx_enrollment)
      expect(context.qle).to eq true
      expect(context.employee_is_shopping_before_hire).to eq true
    end
  end
end