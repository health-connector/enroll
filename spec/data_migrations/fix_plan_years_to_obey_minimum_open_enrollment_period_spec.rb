# frozen_string_literal: true

require "rails_helper"

require File.join(Rails.root, 'app', 'data_migrations', 'fix_plan_years_to_obey_minimum_open_enrollment_period')
describe FixPlanYearsToObeyMinimumOpenEnrollmentPeriod, dbclean: :after_each do

  let(:given_task_name) { 'fix_plan_years_to_obey_minimum_open_enrollment_period' }
  subject { FixPlanYearsToObeyMinimumOpenEnrollmentPeriod.new(given_task_name, double(:current_scope => nil)) }

  describe 'given a task name' do
    it 'has the given task name' do
      expect(subject.name).to eql given_task_name
    end
  end

  describe 'fix bad plan year' do

    context 'change open_enrollment_start_on date' do
      let(:organization)      { FactoryBot.create(:organization)}
      let(:plan_year)         { FactoryBot.build(:plan_year, open_enrollment_start_on: Date.new(2016, 2, 8), open_enrollment_end_on: Date.new(2016, 2, 10), start_on: Date.new(2016, 3, 1)) }
      let(:employer_profile)  { FactoryBot.build(:employer_profile, organization: organization, plan_years: [plan_year]) }

      before(:each) do
        employer_profile.save(validate: false) # Forcing the validation because we want an employer profile with an invalid plan year for the test case.
      end

      after(:all) do
        FileUtils.rm_rf('fix_plan_year_output.txt')
      end

      it 'will set the open_enrollment_start_on date of the plan_year so that it follows the minimum 5 days rule' do
        ClimateControl.modify fein: organization.fein do
          subject.migrate
          plan_year.reload
          expect(plan_year.open_enrollment_end_on.mjd - plan_year.open_enrollment_start_on.mjd).to eq 4
        end
      end
    end
  end
end
