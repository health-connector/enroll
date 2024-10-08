# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "remove_dependent_from_ee_enrollment")

describe RemoveDependentFromEeEnrollment, dbclean: :after_each do
  subject { RemoveDependentFromEeEnrollment.new("remove dependent from ee enrollment", double(:current_scope => nil)) }
  let(:family){FactoryBot.create(:family,:with_primary_family_member)}
  let(:hbx_enrollment_member){ FactoryBot.build(:hbx_enrollment_member, applicant_id: family.family_members.first.id, eligibility_date: TimeKeeper.date_of_record.beginning_of_month) }
  let!(:hbx_enrollment){FactoryBot.create(:hbx_enrollment, hbx_enrollment_members: [hbx_enrollment_member], household: family.active_household)}

  context "won't delete enrollment memeber if not found hbx_enrollment" do
    it "won't delete enrollment memeber if not found hbx_enrollment" do
      ClimateControl.modify enrollment_id: '',enrollment_member_id: hbx_enrollment.hbx_enrollment_members.first.id do
        enrollment_member_id = hbx_enrollment.hbx_enrollment_members.first.id
        expect(hbx_enrollment.hbx_enrollment_members.where(id: enrollment_member_id).size).to eq 1
        subject.migrate
        hbx_enrollment.reload
        expect(hbx_enrollment.hbx_enrollment_members.where(id: enrollment_member_id).size).to eq 1
      end
    end
  end

  context "won't delete enrollment memeber if not found hbx_enrollment_member" do
    it "won't delete enrollment memeber if not found hbx_enrollment" do
      ClimateControl.modify enrollment_id: hbx_enrollment.id, enrollment_member_id: "" do
        enrollment_member_id = hbx_enrollment.hbx_enrollment_members.first.id
        expect(hbx_enrollment.hbx_enrollment_members.where(id: enrollment_member_id).size).to eq 1
        subject.migrate
        hbx_enrollment.reload
        expect(hbx_enrollment.hbx_enrollment_members.where(id: enrollment_member_id).size).to eq 1
      end
    end
  end

  context "will delete enrollment memeber if find hbx_enrollment_member within hbx_enrollment" do
    it "won't delete enrollment memeber if not found hbx_enrollment" do
      ClimateControl.modify enrollment_id: hbx_enrollment.id, enrollment_member_id: hbx_enrollment.hbx_enrollment_members.first.id do

        enrollment_member_id = hbx_enrollment.hbx_enrollment_members.first.id
        expect(hbx_enrollment.hbx_enrollment_members.where(id: enrollment_member_id).size).to eq 1
        subject.migrate
        hbx_enrollment.reload
        expect(hbx_enrollment.hbx_enrollment_members.where(id: enrollment_member_id).size).to eq 0
      end
    end
  end
end
