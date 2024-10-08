# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "migrate_plan_year")

describe MigratePlanYear, dbclean: :after_each do
  let(:given_task_name) { "migrate_plan_year" }
  subject { MigratePlanYear.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "changing plan year's state" do

    let(:benefit_group)     { FactoryBot.build(:benefit_group)}
    let(:plan_year)         { FactoryBot.build(:plan_year, benefit_groups: [benefit_group], aasm_state: "active", is_conversion: true) }
    let(:employer_profile)  { FactoryBot.create(:employer_profile, plan_years: [plan_year], profile_source: "conversion") }

    around do |example|
      ClimateControl.modify feins: employer_profile.parent.fein do
        example.run
      end
    end

    context "giving a new state" do
      it "should change its aasm state when active" do
        subject.migrate
        plan_year.reload
        expect(plan_year.aasm_state).to eq "conversion_expired"
      end

      it "should not change it's state" do
        plan_year.aasm_state = "renewing_enrolling"
        plan_year.save
        subject.migrate
        plan_year.reload
        expect(plan_year.aasm_state).to eq "renewing_enrolling"
      end
    end
  end
end
