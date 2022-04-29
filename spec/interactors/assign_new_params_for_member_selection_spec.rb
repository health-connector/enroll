# frozen_string_literal: true

require "rails_helper"
require './spec//shared_context/setup_shop_families_enrollments'

describe AssignNewParamsForMemberSelection, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'when passed invalid params' do
    it 'should not assign employee_role' do
      context = described_class.call(person: nil, params: {employee_role_id: employee_role.id})
      expect(context.employee_role).to eq nil
    end

    it 'should not assign employee_role' do
      context = described_class.call(person: ee_person, params: {employee_role_id: nil})
      expect(context.employee_role).to eq nil
    end

    it 'should not assign employee_role' do
      ee_person.employee_roles = []
      ee_person.save
      context = described_class.call(person: ee_person, params: {employee_role_id: employee_role.id})
      expect(context.employee_role).to eq nil
    end
  end

  context 'when passed valid params' do
    it 'should assign employee_role' do
      context = described_class.call(person: ee_person, params: {employee_role_id: employee_role.id})
      expect(context.can_shop_shop).to eq true
      expect(context.employee_role).to eq employee_role
    end
  end
end