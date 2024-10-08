# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "remove_coverage_household_member")

describe RemoveCoverageHouseholdMember, dbclean: :after_each do

  let(:given_task_name) { "remove_coverage_household_member" }
  subject { RemoveCoverageHouseholdMember.new(given_task_name, double(:current_scope => nil)) }
  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end
  describe "remove family member from coverage household", dbclean: :after_each do

    let(:person) { FactoryBot.create(:person) }
    let(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person)}
    let(:family_member){ FactoryBot.create(:family_member,family: family, is_active: true)}

    it "should remove a family member to household" do
      chms = family.households.first.coverage_households.first.coverage_household_members << CoverageHouseholdMember.new(family_member_id: family_member.id, is_subscriber: false)
      chm = chms.where(family_member_id: family_member.id).first
      family.save
      ClimateControl.modify person_hbx_id: person.hbx_id, family_member_id: family_member.id,action: "remove_fm_from_ch",coverage_household_member_id: chm.id do

        coverage_household_member = family.households.first.coverage_households.first.coverage_household_members
        expect(coverage_household_member.where(family_member_id: family_member.id).first).not_to eq nil
        subject.migrate
        family.reload
        expect(family.households.first.coverage_households.first.coverage_household_members.size).to eq 1
      end
    end
  end

  describe "remove coverage household member", dbclean: :after_each do

    let(:person) {FactoryBot.create(:person)}
    let(:family) {FactoryBot.create(:family, :with_primary_family_member, person: person)}
    let(:family_member) {FactoryBot.create(:family_member, family: family, is_active: true)}


    it "coverage household member is greater than one" do
      family.households.first.coverage_households.first.coverage_household_members << CoverageHouseholdMember.new(family_member_id: family_member.id, is_subscriber: false)
      chms = family.households.first.coverage_households.first.coverage_household_members << CoverageHouseholdMember.new(family_member_id: family_member.id, is_subscriber: false)
      chm = chms.where(family_member_id: family_member.id)[1]
      ClimateControl.modify person_hbx_id: person.hbx_id, family_member_id: family_member.id,action: "remove_duplicate_chm",coverage_household_member_id: chm.id do
        coverage_household_member = family.households.first.coverage_households.first.coverage_household_members.where(family_member_id: family_member.id)
        expect(coverage_household_member.count).to be > 1
        subject.migrate
        family.reload
        coverage_household_member = family.households.first.coverage_households.first.coverage_household_members.where(family_member_id: family_member.id)
        expect(coverage_household_member.count).to eq 1
      end
    end
  end

  describe "remove invalid family member from coverage household", dbclean: :after_each do

    let(:person) { FactoryBot.create(:person) }
    let(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person)}
    let(:family_member){ FactoryBot.create(:family_member,family: family, is_active: true)}
    let(:action){ "remove_invalid_fm"}

    it "should remove a family member to household" do
      chms = family.households.first.coverage_households.first.coverage_household_members << CoverageHouseholdMember.new(family_member_id: family_member.id, is_subscriber: false)
      chm = chms.where(family_member_id: family_member.id).first
      family.save
      ClimateControl.modify person_hbx_id: person.hbx_id, family_member_id: family_member.id,action: "remove_invalid_fm",coverage_household_member_id: chm.id do

        coverage_household_member = family.households.first.coverage_households.first.coverage_household_members
        expect(coverage_household_member.where(family_member_id: family_member.id).first).not_to eq nil
        subject.migrate
        family.reload
        expect(family.households.first.coverage_households.first.coverage_household_members.size).to eq 1
      end
    end
  end
end
