# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "change_ce_date_of_termination")

describe ChangeCeDateOfTermination do

  describe "given a task name" do
    let(:given_task_name) { "change_ce_date_of_termination" }
    subject { ChangeCeDateOfTermination.new(given_task_name, double(:current_scope => nil)) }

    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  context "of the environment's 'ssn' and 'date_of_terminate' variables being set" do
    around do |example|
      ClimateControl.modify ssn: census_employee.ssn, date_of_terminate: date do
        example.run
      end
    end

    describe "census employee not in terminated state", dbclean: :after_each do
      subject { ChangeCeDateOfTermination.new("change_ce_date_of_termination", double(:current_scope => nil)) }

      let(:employer_profile) { census_employee.employer_profile }
      let(:employer_profile_id) { employer_profile.id }
      let(:census_employee) { FactoryBot.create(:census_employee, hired_on: (TimeKeeper.date_of_record - 2.years).strftime("%Y-%m-%d")) }
      let(:date) { (TimeKeeper.date_of_record - 2.days).to_s }

      before :each do
        census_employee.aasm_state = "employment_terminated"
        census_employee.save
        subject.migrate
        census_employee.reload
      end

      it "should not change dot of ce not in employment termination state" do
        expect(census_employee.employment_terminated_on.to_s).to eq date
      end
    end

    describe "census employee's in terminated state", dbclean: :after_each do
      subject { ChangeCeDateOfTermination.new("termiante_census_employee", double(:current_scope => nil)) }

      let(:employer_profile) { census_employee.employer_profile }
      let(:employer_profile_id) { employer_profile.id }
      let(:date) {  (TimeKeeper.date_of_record - 1.days).to_s }
      let(:census_employee) { FactoryBot.create(:census_employee, hired_on: (TimeKeeper.date_of_record - 2.days)) }

      before :each do
        census_employee.aasm_state = "employment_terminated"
        census_employee.save
        subject.migrate
        census_employee.reload
      end

      it "should change dot of ce not in employment termination state" do
        ce = CensusEmployee.by_ssn(census_employee.ssn).first
        expect(ce.employment_terminated_on.to_s).to eq date
      end
    end
  end
end
