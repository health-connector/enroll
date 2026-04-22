# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CensusEmployee, type: :model do
  describe '#is_employee_covered?' do
    let(:census_employee) { CensusEmployee.new }

    context 'when there is no active or renewal assignment' do
      it 'returns false' do
        allow(census_employee).to receive(:renewal_benefit_group_assignment).and_return(nil)
        allow(census_employee).to receive(:active_benefit_group_assignment).and_return(nil)

        expect(census_employee.is_employee_covered?).to eq(false)
      end
    end

    context 'when an assignment exists' do
      it 'returns true when covered families present' do
        bga = double('BGA', covered_families_with_benefit_assignment: [double])
        allow(census_employee).to receive(:renewal_benefit_group_assignment).and_return(nil)
        allow(census_employee).to receive(:active_benefit_group_assignment).and_return(bga)

        expect(census_employee.is_employee_covered?).to eq(true)
      end

      it 'returns false when covered families empty' do
        bga = double('BGA', covered_families_with_benefit_assignment: [])
        allow(census_employee).to receive(:renewal_benefit_group_assignment).and_return(nil)
        allow(census_employee).to receive(:active_benefit_group_assignment).and_return(bga)

        expect(census_employee.is_employee_covered?).to eq(false)
      end
    end
  end
end
