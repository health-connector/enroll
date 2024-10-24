# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "add_hbx_enrollment_member")
describe AddHbxEnrollmentMember, dbclean: :after_each do
  let(:given_task_name) { "add_hbx_enrollment_member" }
  subject { AddHbxEnrollmentMember.new(given_task_name, double(:current_scope => nil)) }
  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "creating new enrollment member record for an enrollment", dbclean: :after_each do
    let(:family) { FactoryBot.create(:family, :with_primary_family_member) }
    let(:enrollment) do
      hbx = FactoryBot.create(:hbx_enrollment, household: family.active_household, kind: "individual")
      hbx.hbx_enrollment_members << FactoryBot.build(:hbx_enrollment_member, applicant_id: family.family_members.first.id, is_subscriber: true, eligibility_date: TimeKeeper.date_of_record - 30.days)
      hbx.save
      hbx
    end
    let(:family_member) { FactoryBot.create(:family_member, family: family)}

    it "should create a new enrollment member record" do
      ClimateControl.modify hbx_id: enrollment.hbx_id.to_s,family_member_id: family_member.id do
        hem_size = enrollment.hbx_enrollment_members.count
        subject.migrate
        enrollment.reload
        expect(enrollment.hbx_enrollment_members.count).to eq(hem_size + 1)
      end
    end

    it "should not create a new enrollment member record if it already exists under enrollment" do
      ClimateControl.modify hbx_id: enrollment.hbx_id.to_s,family_member_id: family_member.id do

        enrollment.hbx_enrollment_members << FactoryBot.build(:hbx_enrollment_member, applicant_id: family_member.id, is_subscriber: false, eligibility_date: TimeKeeper.date_of_record - 30.days)
        enrollment.save
        hem_size = enrollment.hbx_enrollment_members.count
        subject.migrate
        enrollment.reload
        expect(enrollment.hbx_enrollment_members.count).to eq hem_size
      end
    end
  end

  describe "creating primary member record for an enrollment", dbclean: :after_each do
    let(:family) { FactoryBot.create(:family, :with_primary_family_member) }
    let(:enrollment){ FactoryBot.create(:hbx_enrollment, household: family.active_household, kind: "employer_sponsored") }
    let(:family_member) { FactoryBot.create(:family_member, family: family)}

    it "should create a new enrollment member record" do
      ClimateControl.modify hbx_id: enrollment.hbx_id.to_s,family_member_id: family_member.id, coverage_start_on: enrollment.effective_on.strftime("%Y-%m-%d").to_s do
        hem_size = enrollment.hbx_enrollment_members.count
        subject.migrate
        enrollment.reload
        expect(enrollment.hbx_enrollment_members.count).to eq(hem_size + 1)
      end
    end

    it "should not create a new enrollment member record if it already exists under enrollment" do
      ClimateControl.modify hbx_id: enrollment.hbx_id.to_s,family_member_id: family_member.id, coverage_start_on: enrollment.effective_on.to_s do

        enrollment.hbx_enrollment_members << FactoryBot.build(:hbx_enrollment_member, applicant_id: family_member.id, is_subscriber: true, eligibility_date: enrollment.effective_on)
        enrollment.save
        hem_size = enrollment.hbx_enrollment_members.count
        subject.migrate
        enrollment.reload
        expect(enrollment.hbx_enrollment_members.count).to eq hem_size
      end
    end
  end
end




