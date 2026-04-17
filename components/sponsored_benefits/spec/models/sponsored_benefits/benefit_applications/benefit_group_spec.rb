require 'rails_helper'

module SponsoredBenefits
  RSpec.describe BenefitApplications::BenefitGroup, type: :model do
    describe '#delete_benefit_group_assignments_and_enrollments' do
      subject(:delete_assignments_and_enrollments) { benefit_group.delete_benefit_group_assignments_and_enrollments }

      let(:benefit_group) { described_class.new }
      let(:benefit_group_id) { BSON::ObjectId.new }
      let(:remaining_benefit_group) { instance_double(described_class, id: BSON::ObjectId.new) }
      let(:benefit_application) { instance_double('SponsoredBenefits::BenefitApplications::BenefitApplication', benefit_groups: [benefit_group, remaining_benefit_group]) }
      let(:enrollment_1) { instance_double(HbxEnrollment.to_s) }
      let(:enrollment_2) { instance_double(HbxEnrollment.to_s) }
      let(:benefit_group_assignment) { instance_double(BenefitGroupAssignment.to_s, hbx_enrollments: [enrollment_1, enrollment_2]) }
      let(:assignments_relation) { instance_double(Mongoid::Criteria.to_s) }
      let(:census_employee) { instance_double(CensusEmployee.to_s, benefit_group_assignments: assignments_relation) }

      before do
        allow(benefit_group).to receive(:id).and_return(benefit_group_id)
        allow(benefit_group).to receive(:benefit_application).and_return(benefit_application)
        allow(benefit_group).to receive(:census_employees).and_return([census_employee])

        allow(assignments_relation).to receive(:where).with(benefit_group_id: benefit_group_id).and_return([benefit_group_assignment])
        allow(enrollment_1).to receive(:destroy)
        allow(enrollment_2).to receive(:destroy)
        allow(benefit_group_assignment).to receive(:destroy)
        allow(census_employee).to receive(:create_benefit_group_assignment)
      end

      it 'destroys related enrollments and assignment for matching benefit group' do
        expect(enrollment_1).to receive(:destroy)
        expect(enrollment_2).to receive(:destroy)
        expect(benefit_group_assignment).to receive(:destroy)

        delete_assignments_and_enrollments
      end

      it 'creates a new assignment on the remaining benefit group' do
        expect(census_employee).to receive(:create_benefit_group_assignment).with(remaining_benefit_group)

        delete_assignments_and_enrollments
      end

      context 'when there are no matching assignments for the benefit group' do
        before do
          allow(assignments_relation).to receive(:where).with(benefit_group_id: benefit_group_id).and_return([])
        end

        it 'does not create a new assignment' do
          expect(census_employee).not_to receive(:create_benefit_group_assignment)

          delete_assignments_and_enrollments
        end
      end

      context 'when there is no remaining benefit group' do
        let(:benefit_application) { instance_double('SponsoredBenefits::BenefitApplications::BenefitApplication', benefit_groups: [benefit_group]) }

        it 'does not create a new assignment' do
          expect(census_employee).not_to receive(:create_benefit_group_assignment)

          delete_assignments_and_enrollments
        end
      end
    end
  end
end
