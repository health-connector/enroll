# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "match_coverage_household_with_family_member")

describe MatchCoverageHouseholdWithFamilyMember, dbclean: :after_each do

  let(:given_task_name) { "match_coverage_household_with_family_member" }
  subject { MatchCoverageHouseholdWithFamilyMember.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "matching coverage household with family members", dbclean: :after_each do

    let(:person) { FactoryBot.create(:person) }
    let(:family) { FactoryBot.create(:family, :with_primary_family_member_and_dependent, person: person)}
    let(:coverage_household) { family.latest_household.coverage_households.first }

    context 'When family member has empty coverage household members' do
      before do
        coverage_household.coverage_household_members.last.destroy
      end
      it "should add a coverage household members for familiy members" do
        ClimateControl.modify hbx_id: person.hbx_id do
          expect(coverage_household.coverage_household_members.size).to eq(2)
          subject.migrate
          coverage_household.reload
          expect(coverage_household.coverage_household_members.size).to eq(3)
        end
      end
    end

    context 'When family member has unnecessary  coverage household family members' do
      before do
        coverage_household.coverage_household_members.create(family_member_id: 'hffh5as76d57a')
      end
      it "should remove the coverage household members that is not related to family members" do
        ClimateControl.modify hbx_id: person.hbx_id do
          expect(coverage_household.coverage_household_members.size).to eq(4)
          subject.migrate
          coverage_household.reload
          expect(coverage_household.coverage_household_members.size).to eq(3)
        end
      end
    end
  end
end
