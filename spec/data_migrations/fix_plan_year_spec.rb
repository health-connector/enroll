# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "fix_plan_year")

describe FixPlanYear, dbclean: :after_each do

  let(:given_task_name) { "fix_plan_year_state" }
  subject { FixPlanYear.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "updating plan year and enrollments" do

    let(:organization) { FactoryBot.create(:organization)}
    let(:benefit_group)     { FactoryBot.build(:benefit_group, effective_on_kind: "date_of_hire")}
    let(:plan_year)         { FactoryBot.build(:plan_year, benefit_groups: [benefit_group]) }
    let!(:employer_profile)  { FactoryBot.create(:employer_profile, organization: organization, plan_years: [plan_year]) }
    let(:term_date) {TimeKeeper.date_of_record.at_beginning_of_month.next_month}
    let(:person) { FactoryBot.create(:person) }
    let(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person)}
    let(:hbx_enrollment) { FactoryBot.create(:hbx_enrollment, benefit_group_id: benefit_group.id,household: family.active_household)}
    let(:hbx_enrollment2) { FactoryBot.create(:hbx_enrollment, benefit_group_id: benefit_group.id,household: family.active_household)}

    context "termianted plan year to active plan year" do

      before :each do
        plan_year.update_attributes(aasm_state: 'terminated', terminated_on: term_date, end_on: term_date)
        hbx_enrollment.update_attributes(aasm_state: 'coverage_terminated',terminated_on: term_date)
      end

      it "should make plan year & enrollments active " do
        ClimateControl.modify fein: organization.fein,
                              start_on: plan_year.start_on.to_s,
                              end_on: ((plan_year.start_on + 1.year) - 1.day).to_s,
                              aasm_state: 'active',
                              terminated_on: '',
                              update_enrollments: 'true' do

          expect(plan_year.aasm_state).to eq 'terminated'   # before migration
          expect(plan_year.terminated_on).to eq term_date
          expect(hbx_enrollment.aasm_state).to eq 'coverage_terminated'
          subject.migrate
          plan_year.reload
          hbx_enrollment.reload
          expect(plan_year.aasm_state).to eq 'active'  # after migration
          expect(plan_year.terminated_on).to eq nil
          expect(hbx_enrollment.aasm_state).to eq 'coverage_selected'
        end
      end
    end
    context "termianted plan year to cancelled plan year" do

      before :each do
        # allow(ENV).to receive(:[]).with("fein").and_return organization.fein
        # allow(ENV).to receive(:[]).with("start_on").and_return plan_year.start_on
        # allow(ENV).to receive(:[]).with("end_on").and_return (plan_year.start_on-1.day) + 1.year
        # allow(ENV).to receive(:[]).with("aasm_state").and_return 'canceled'
        # allow(ENV).to receive(:[]).with("terminated_on").and_return ''
        # allow(ENV).to receive(:[]).with("update_enrollments").and_return "true"
        plan_year.update_attributes(aasm_state: 'terminated', terminated_on: term_date, end_on: term_date)
        hbx_enrollment.update_attributes(aasm_state: 'coverage_terminated',terminated_on: term_date)
        hbx_enrollment2.update_attributes(aasm_state: 'shopping',terminated_on: term_date)
      end

      it "should make plan year & enrollments active " do
        ClimateControl.modify fein: organization.fein,
                              start_on: plan_year.start_on.to_s,
                              end_on: ((plan_year.start_on - 1.day) + 1.year).to_s,
                              aasm_state: 'canceled',
                              terminated_on: '',
                              update_enrollments: 'true' do
          expect(plan_year.aasm_state).to eq 'terminated'   # before migration
          expect(plan_year.terminated_on).to eq term_date
          expect(hbx_enrollment.aasm_state).to eq 'coverage_terminated'
          expect(hbx_enrollment2.aasm_state).to eq 'shopping'
          subject.migrate
          plan_year.reload
          hbx_enrollment.reload
          expect(plan_year.aasm_state).to eq 'canceled'  # after migration
          expect(plan_year.terminated_on).to eq nil
          expect(hbx_enrollment.aasm_state).to eq 'coverage_canceled'
          expect(hbx_enrollment2.aasm_state).to eq 'shopping'
        end
      end

      it "should not update enrollments " do
        ClimateControl.modify fein: organization.fein,
                              start_on: plan_year.start_on.to_s,
                              end_on: ((plan_year.start_on - 1.day) + 1.year).to_s,
                              aasm_state: 'canceled',
                              terminated_on: '',
                              update_enrollments: 'false' do
          expect(plan_year.aasm_state).to eq 'terminated'   # before migration
          expect(plan_year.terminated_on).to eq term_date
          expect(hbx_enrollment.aasm_state).to eq 'coverage_terminated'
          expect(hbx_enrollment2.aasm_state).to eq 'shopping'
          subject.migrate
          plan_year.reload
          hbx_enrollment.reload
          expect(plan_year.aasm_state).to eq 'canceled'  # after migration
          expect(plan_year.terminated_on).to eq nil
          expect(hbx_enrollment.aasm_state).to eq 'coverage_terminated'
          expect(hbx_enrollment2.aasm_state).to eq 'shopping'
        end
      end
    end
  end
end


