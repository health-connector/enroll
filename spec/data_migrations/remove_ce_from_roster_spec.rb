# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "remove_ce_from_roster")

describe RemoveCeFromRoster, dbclean: :after_each do
  let(:given_task_name) { "remove_ce_from_roster" }
  subject { RemoveCeFromRoster.new(given_task_name, double(:current_scope => nil)) }
  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end
  describe "remove census_employee" do
    let(:employer_profile)     { FactoryBot.create(:employer_profile) }
    let(:census_employee)     { FactoryBot.create(:census_employee, employer_profile_id: employer_profile.id) }
    it "should remove the census employee from the employer" do
      ClimateControl.modify ce_id: census_employee.id.to_s do
        ce_id = census_employee.id
        expect(employer_profile.census_employees.where(id: ce_id).size).to eq 1
        subject.migrate
        employer_profile.reload
        expect(employer_profile.census_employees.where(id: ce_id).size).to eq 0
      end
    end
  end
end
