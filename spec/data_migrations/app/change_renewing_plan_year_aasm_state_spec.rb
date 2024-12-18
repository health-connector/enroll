# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "change_renewing_plan_year_aasm_state")


describe ChangeRenewingPlanYearAasmState, dbclean: :after_each do
  skip "DEPRECATED rake was never updated to new model, check if we can remove it" do

    let(:given_task_name) { "change_renewing_plan_year_aasm_state" }
    let!(:rating_area) { RatingArea.first || FactoryBot.create(:rating_area)  }
    subject { ChangeRenewingPlanYearAasmState.new(given_task_name, double(:current_scope => nil)) }

    describe "given a task name" do
      it "has the given task name" do
        expect(subject.name).to eql given_task_name
      end
    end

    describe "updating aasm_state of the renewing plan year", dbclean: :after_each do
      let!(:family) { FactoryBot.create(:family, :with_primary_family_member)}

      let!(:renewal_plan) {FactoryBot.create(:plan, active_year: TimeKeeper.date_of_record.year)}
      let(:active_benefit_group_ref_plan) {FactoryBot.create(:plan, active_year: TimeKeeper.date_of_record.year - 1,renewal_plan_id: renewal_plan.id)}

      let(:benefit_group) { FactoryBot.build(:benefit_group, reference_plan_id: active_benefit_group_ref_plan.id, elected_plan_ids: [active_benefit_group_ref_plan.id]) }
      let!(:renewal_benefit_group) { FactoryBot.build(:benefit_group, reference_plan_id: renewal_plan.id, elected_plan_ids: [renewal_plan.id],plan_year: plan_year) }

      let(:active_plan_year){ FactoryBot.build(:plan_year,start_on: TimeKeeper.date_of_record.beginning_of_month - 1.year, end_on: TimeKeeper.date_of_record.last_month.end_of_month, aasm_state: "expired",benefit_groups: [benefit_group]) }
      let(:plan_year){ FactoryBot.build(:plan_year, aasm_state: "renewing_publish_pending") }
      let(:plan_year2){ FactoryBot.build(:plan_year, aasm_state: "renewing_canceled") }

      let(:employer_profile){ FactoryBot.build(:employer_profile, plan_years: [active_plan_year,plan_year, plan_year2]) }
      let(:organization)  {FactoryBot.create(:organization,employer_profile: employer_profile)}

      let(:benefit_group_assignment) { FactoryBot.build(:benefit_group_assignment, start_on: active_plan_year.start_on, benefit_group: benefit_group)}
      let(:renewal_benefit_group_assignment) { FactoryBot.build(:benefit_group_assignment, start_on: plan_year.start_on, benefit_group: renewal_benefit_group)}
      let(:employee_role) { FactoryBot.create(:employee_role)}
      let(:census_employee) { FactoryBot.create(:census_employee,employer_profile: employer_profile,benefit_group_assignments: [benefit_group_assignment,renewal_benefit_group_assignment],employee_role_id: employee_role.id) }

      let(:person) {FactoryBot.create(:person,ssn: census_employee.ssn)}
      let(:family) { FactoryBot.create(:family, :with_primary_family_member,person: person)}

      let(:enrollment) do
        FactoryBot.create(:hbx_enrollment, effective_on: active_plan_year.start_on,aasm_state: 'coverage_selected',plan_id: active_benefit_group_ref_plan.id,benefit_group_id: benefit_group.id, household: family.active_household,
                                           benefit_group_assignment_id: benefit_group_assignment.id)
      end
      let(:active_household) {family.active_household}

      around do |example|
        ClimateControl.modify state: '',
                              py_aasm_state: 'renewing_publish_pending',
                              fein: organization.fein,
                              plan_year_start_on: plan_year.start_on do
          example.run
        end
      end

      before(:each) do
        active_household.hbx_enrollments = [enrollment]
        active_household.save!
      end

      it "should update aasm_state of plan year to renewing_enrolling when no enrollment present" do
        allow_any_instance_of(PlanYear).to receive(:is_enrollment_valid?).and_return(false)
        subject.migrate
        plan_year.reload
        expect(plan_year.aasm_state).to eq "renewing_enrolling"
        expect(plan_year2.aasm_state).to eq "renewing_canceled"
      end

      it "should not should update aasm_state of plan year when ENV['plan_year_start_on'] is empty" do
        ClimateControl.modify(
          plan_year_start_on: ''
        ) do
          subject.migrate
          plan_year.reload
          expect(plan_year.aasm_state).to eq "renewing_publish_pending"
        end
      end

      ["renewing_publish_pending", "renewing_application_ineligible"].each do |plan_year_state|
        it "should update aasm_state of plan year" do
          ClimateControl.modify(
            py_aasm_state: plan_year_state
          ) do
            allow_any_instance_of(PlanYear).to receive(:is_enrollment_valid?).and_return(false)
            plan_year.update_attributes(aasm_state: plan_year_state)
            subject.migrate
            plan_year.reload
            expect(plan_year.aasm_state).to eq "renewing_enrolling"
          end
        end
      end

      it "should update aasm_state of plan year to renewing_enrolling when OE closed and has valid enrollment but has no state specified" do
        allow_any_instance_of(PlanYear).to receive(:is_enrollment_valid?).and_return(true)
        allow_any_instance_of(PlanYear).to receive(:is_open_enrollment_closed?).and_return(true)
        allow_any_instance_of(PlanYear).to receive(:may_activate?).and_return(false)
        census_employee.reload
        subject.migrate
        plan_year.reload
        expect(plan_year.aasm_state).to eq "renewing_enrolling"
      end

      it "should update aasm_state of plan year to renewing_enrolled when OE closed and has valid enrollment" do
        allow_any_instance_of(PlanYear).to receive(:is_enrollment_valid?).and_return(true)
        allow_any_instance_of(PlanYear).to receive(:is_open_enrollment_closed?).and_return(true)
        allow_any_instance_of(PlanYear).to receive(:may_activate?).and_return(false)
        ClimateControl.modify(
          state: 'renewing_enrolled'
        ) do
          census_employee.reload
          subject.migrate
          plan_year.reload
          expect(plan_year.aasm_state).to eq "renewing_enrolled"
        end
      end

      it "should update aasm_state of plan year to active if plan year can be activated" do
        allow_any_instance_of(PlanYear).to receive(:is_enrollment_valid?).and_return(true)
        allow_any_instance_of(PlanYear).to receive(:is_open_enrollment_closed?).and_return(true)
        allow_any_instance_of(PlanYear).to receive(:can_be_activated?).and_return(true)
        ClimateControl.modify(
          state: 'renewing_enrolled'
        ) do
          active_household.reload
          census_employee.reload
          subject.migrate
          active_household.reload
          census_employee.reload
          plan_year.reload
          expect(census_employee.active_benefit_group_assignment).to eq renewal_benefit_group_assignment  # should update benefit_group_assignment
          expect(plan_year.aasm_state).to eq "active"
          expect(employer_profile.plan_years.map(&:aasm_state)).to eq ["expired", "active", "renewing_canceled"]
          expect(family.active_household.hbx_enrollments.map(&:aasm_state)).to eq ["coverage_expired", "coverage_enrolled"]
        end
      end
    end
  end
end
