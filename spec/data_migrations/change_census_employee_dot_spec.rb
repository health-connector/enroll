# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "change_census_employee_dot")

describe ChangeCensusEmployeeDot, dbclean: :around_each do
  describe "given a task name" do
    let(:given_task_name) { "change_census_employee_dot" }
    subject {ChangeCensusEmployeeDot.new(given_task_name, double(:current_scope => nil)) }
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "census employee not in terminated state" do
    subject {ChangeCensusEmployeeDot.new("change_census_employee_dot", double(:current_scope => nil)) }
    let(:employer_profile){ FactoryBot.create(:employer_profile) }
    let(:employer_profile_id){ employer_profile.id }
    let(:census_employee){ FactoryBot.create(:census_employee, employer_profile_id: employer_profile.id, employment_terminated_on: TimeKeeper.date_of_record - 5.days, hired_on: "2014-11-11") }
    let(:census_employee_params) do
      {
        "hired_on" => "05/02/2015",
        "employer_profile_id" => employer_profile_id
      }
    end

    let(:date) { TimeKeeper.date_of_record.next_month.beginning_of_month + 2.days }
    let(:date1){TimeKeeper.date_of_record - 5.days}

    before :each do
      ClimateControl.modify census_employee_id: census_employee.id, new_dot: "01/01/2016" do
        census_employee.aasm_state = "employee_termination_pending"
        census_employee.save!
        subject.migrate
        census_employee.reload
      end
    end

    it "should change dot of ce not in employment termination state" do
      expect(census_employee.employment_terminated_on).to eq Date.new(2016,0o1,0o1)
      expect(census_employee.aasm_state).to eq "employment_terminated"
    end
  end

  describe "census employee's in terminated state" do
    subject {ChangeCensusEmployeeDot.new("change_census_employee_dot", double(:current_scope => nil)) }
    let(:employer_profile) { FactoryBot.create(:employer_profile) }
    let(:employer_profile_id) { employer_profile.id }
    let(:census_employee) { FactoryBot.create(:census_employee, employer_profile_id: employer_profile.id,employment_terminated_on: TimeKeeper.date_of_record - 5.days, hired_on: "2014-11-11") }
    let(:census_employee_params) do
      {
        "hired_on" => "05/02/2015",
        "employer_profile_id" => employer_profile_id
      }
    end
    let(:date) {TimeKeeper.date_of_record - 1.days }

    before :each do
      ClimateControl.modify census_employee_id: census_employee.id, new_dot: "01/01/2016" do
        census_employee.aasm_state = "employment_terminated"
        census_employee.save
        subject.migrate
        census_employee.reload
      end
    end

    it "should change dot of ce not in employment termination state" do
      ce = CensusEmployee.find(census_employee.id)
      expect(ce.employment_terminated_on).to eq Date.new(2016,0o1,0o1)
    end
  end
end
