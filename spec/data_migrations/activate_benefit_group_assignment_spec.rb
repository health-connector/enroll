require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "activate_benefit_group_assignment")

describe ActivateBenefitGroupAssignment, dbclean: :after_each do

  let(:given_task_name) { "activate_benefit_group_assignment" }
  subject { ActivateBenefitGroupAssignment.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "activate benefit group assignment" do
    let!(:census_employee)            { FactoryGirl.create(:census_employee)}
    let!(:benefit_group_assignment1)  { FactoryGirl.create(:benefit_group_assignment, is_active: false, census_employee: census_employee)}
    let!(:benefit_group_assignment2)  { FactoryGirl.create(:benefit_group_assignment, is_active: false, census_employee: census_employee)}

    context "activate_benefit_group_assignment" do

      before(:each) do
        allow(ENV).to receive(:[]).with("bga_id").and_return(benefit_group_assignment1.id)
        subject.migrate
        census_employee.reload
      end

      it "should activate_related_benefit_group_assignment" do
        expect(census_employee.benefit_group_assignments.find(benefit_group_assignment1.id).is_active).to eq true
      end

      it "should_not activate_unrelated_benefit_group_assignment" do
        expect(census_employee.benefit_group_assignments.find(benefit_group_assignment2.id).is_active).to eq false
      end
    end
  end
end
