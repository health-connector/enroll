# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Effective::Datatables::FamilyDataTable, type: :model, dbclean: :after_each do
  include Config::AcaModelConcern

  let(:current_user) { FactoryBot.create(:user, :hbx_staff) }
  let(:family) { FactoryBot.create(:family, :with_primary_family_member) }
  let(:household) { family.active_household }
  let(:person) { family.primary_applicant.person }

  let(:datatable) { described_class.new({}, current_user: current_user) }

  describe '#active_enrollments column' do
    let(:active_enrollments_proc) do
      datatable.table_columns.values.find { |col| col["label"] == "Active Enrollments?" }["proc"]
    end

    context 'when family has only external enrollments' do
      let!(:external_enrollment) do
        FactoryBot.create(:hbx_enrollment,
          household: household,
          aasm_state: 'coverage_selected',
          external_enrollment: true,
          kind: 'individual')
      end

      it 'returns "No" for active_enrollments column' do
        result = active_enrollments_proc.call(family)
        expect(result).to eq "No"
      end

      it 'excludes external enrollments from active.enrolled_and_renewing.non_external scope' do
        active_enrollments = household.hbx_enrollments.non_external.active.enrolled_and_renewing
        expect(active_enrollments).to be_empty
      end

      it 'does not include external enrollment in non_external scope' do
        non_external_enrollments = household.hbx_enrollments.non_external
        expect(non_external_enrollments).to be_empty
      end
    end

    context 'when family has non-external enrollments' do
      let!(:non_external_enrollment) do
        FactoryBot.create(:hbx_enrollment,
          household: household,
          aasm_state: 'coverage_selected',
          external_enrollment: false,
          kind: 'individual')
      end

      it 'returns "Yes" for active_enrollments column' do
        result = active_enrollments_proc.call(family)
        expect(result).to eq "Yes"
      end

      it 'includes non-external enrollments in non_external.active.enrolled_and_renewing scope' do
        active_enrollments = household.hbx_enrollments.non_external.active.enrolled_and_renewing
        expect(active_enrollments).to include(non_external_enrollment)
      end

      it 'includes non-external enrollment in non_external scope' do
        non_external_enrollments = household.hbx_enrollments.non_external
        expect(non_external_enrollments).to include(non_external_enrollment)
      end
    end

    context 'when family has both external and non-external enrollments' do
      let!(:external_enrollment) do
        FactoryBot.create(:hbx_enrollment,
          household: household,
          aasm_state: 'coverage_selected',
          external_enrollment: true,
          kind: 'individual')
      end

      let!(:non_external_enrollment) do
        FactoryBot.create(:hbx_enrollment,
          household: household,
          aasm_state: 'coverage_selected',
          external_enrollment: false,
          kind: 'individual')
      end

      it 'returns "Yes" when non-external enrollments are present' do
        result = active_enrollments_proc.call(family)
        expect(result).to eq "Yes"
      end

      it 'only includes non-external enrollments in non_external.active.enrolled_and_renewing scope' do
        active_enrollments = household.hbx_enrollments.non_external.active.enrolled_and_renewing
        expect(active_enrollments).to include(non_external_enrollment)
        expect(active_enrollments).not_to include(external_enrollment)
      end

      it 'non_external scope properly filters out external enrollments' do
        non_external_enrollments = household.hbx_enrollments.non_external
        expect(non_external_enrollments).to include(non_external_enrollment)
        expect(non_external_enrollments).not_to include(external_enrollment)
      end
    end

    context 'when family has no enrollments' do
      it 'returns "No" for active_enrollments column' do
        result = active_enrollments_proc.call(family)
        expect(result).to eq "No"
      end

      it 'returns empty collection for non_external.active.enrolled_and_renewing scope' do
        active_enrollments = household.hbx_enrollments.non_external.active.enrolled_and_renewing
        expect(active_enrollments).to be_empty
      end
    end

    context 'when family has inactive non-external enrollments' do
      let!(:inactive_enrollment) do
        FactoryBot.create(:hbx_enrollment,
          household: household,
          aasm_state: 'coverage_canceled',
          external_enrollment: false,
          kind: 'individual')
      end

      it 'returns "No" for active_enrollments column' do
        result = active_enrollments_proc.call(family)
        expect(result).to eq "No"
      end

      it 'excludes inactive enrollments from active scope' do
        active_enrollments = household.hbx_enrollments.non_external.active.enrolled_and_renewing
        expect(active_enrollments).not_to include(inactive_enrollment)
      end
    end

    context 'when family has external enrollments in different states' do
      let!(:external_coverage_selected) do
        FactoryBot.create(:hbx_enrollment,
          household: household,
          aasm_state: 'coverage_selected',
          external_enrollment: true,
          kind: 'individual')
      end

      let!(:external_auto_renewing) do
        FactoryBot.create(:hbx_enrollment,
          household: household,
          aasm_state: 'auto_renewing',
          external_enrollment: true,
          kind: 'individual')
      end

      it 'returns "No" for active_enrollments column' do
        result = active_enrollments_proc.call(family)
        expect(result).to eq "No"
      end

      it 'excludes all external enrollments regardless of state' do
        active_enrollments = household.hbx_enrollments.non_external.active.enrolled_and_renewing
        expect(active_enrollments).to be_empty
      end
    end

    context 'testing enrolled_and_renewing scope with external enrollments' do
      let!(:external_renewing) do
        FactoryBot.create(:hbx_enrollment,
          household: household,
          aasm_state: 'renewing_coverage_selected',
          external_enrollment: true,
          kind: 'individual')
      end

      let!(:non_external_renewing) do
        FactoryBot.create(:hbx_enrollment,
          household: household,
          aasm_state: 'renewing_coverage_selected',
          external_enrollment: false,
          kind: 'individual')
      end

      it 'only includes non-external renewing enrollments' do
        result = active_enrollments_proc.call(family)
        expect(result).to eq "Yes"
        
        active_enrollments = household.hbx_enrollments.non_external.active.enrolled_and_renewing
        expect(active_enrollments).to include(non_external_renewing)
        expect(active_enrollments).not_to include(external_renewing)
      end
    end
  end
end