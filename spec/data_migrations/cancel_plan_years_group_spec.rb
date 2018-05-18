require "rails_helper"
 require File.join(Rails.root, "app", "data_migrations", "cancel_plan_years_group")

describe "Importing data" do
    let!(:given_task_name) { "cancel_plan_years_group" }
    let!(:employer_profile) { FactoryGirl.create(:employer_profile, :fein => 1234567) }
    let!(:benefit_group)     { FactoryGirl.build(:benefit_group)}
    let!(:plan_year1)         { FactoryGirl.create(:plan_year, benefit_groups: [benefit_group], aasm_state: "application_ineligible") }
    let!(:plan_year2) {FactoryGirl.create(:plan_year, aasm_state: "active", )}
    let!(:plan_years) {double}
  	subject { CancelPlanYearsGroup.new(given_task_name, double(:current_scope => nil)) }

    before :each do      
      allow(EmployerProfile).to receive(:find_by_fein).and_return(employer_profile)
      allow(employer_profile).to receive(:plan_years).and_return(plan_years)
      allow(plan_years).to receive(:where).and_return([plan_year1])
      allow(ENV).to receive(:[]).with('file_name').and_return "spec/test_data/cancel_plan_years/CancelPlanYears.csv"
    end

    it "should cancel the plan year" do
      subject.migrate
      expect(plan_year1.aasm_state).to eq("canceled")
    end
    it "should not cancel the plan year" do
      subject.migrate
      expect(plan_year2.aasm_state).to eq("active")
    end
end