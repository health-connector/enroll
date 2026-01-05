# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "add_and_remove_enrollment_member")

describe AddAndRemoveEnrollmentMember, dbclean: :after_each do

  let(:given_task_name) { "add_and_remove_enrollment_member" }
  subject { AddAndRemoveEnrollmentMember.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "changing enrollment members" do
    let(:family) { FactoryBot.create(:family, :with_primary_family_member_and_dependent)}
    let(:primary) { family.primary_family_member }
    let(:dependents) { family.dependents }
    let(:hbx_enrollment) { FactoryBot.create(:hbx_enrollment, household: family.active_household)}
    let(:date) { DateTime.now - 10.days }
    let(:subscriber) { FactoryBot.create(:hbx_enrollment_member, hbx_enrollment: hbx_enrollment, eligibility_date: date, coverage_start_on: date, applicant_id: primary.id) }
    let(:hbx_en_member1) do
      FactoryBot.create(:hbx_enrollment_member,
                        hbx_enrollment: hbx_enrollment,
                        eligibility_date: date,
                        coverage_start_on: date,
                        applicant_id: dependents.first.id)
    end

    let(:new_member) do
      HbxEnrollmentMember.new({
                                applicant_id: dependents.last.id,
                                eligibility_date: date,
                                coverage_start_on: date
                              })
    end

    before do
      hbx_enrollment.hbx_enrollment_members = [subscriber, hbx_en_member1]
      hbx_enrollment.save!

      # Set up people with hbx_ids for the migration to find
      primary.person.update_attributes(hbx_id: "primary_hbx_id")
      dependents.first.person.update_attributes(hbx_id: "dependent_1_hbx_id")
      dependents.last.person.update_attributes(hbx_id: "dependent_2_hbx_id")
    end

    shared_examples_for "update members for hbx_enrollment" do |test_params|
      before do
        allow(subject).to receive(:enrollment_input).and_return(hbx_enrollment.hbx_id)
        allow(subject).to receive(:person_to_remove_input).and_return(test_params[:remove_hbx_id] || 'skip')
        allow(subject).to receive(:person_to_add_input).and_return(test_params[:add_hbx_id] || 'skip')
        subject.migrate
        hbx_enrollment.reload
      end

      it "hbx_enrollment has #{test_params[:result_count]} members" do
        expect(hbx_enrollment.hbx_enrollment_members.count).to eq test_params[:result_count].to_i
      end

      it "enrollment subscriber presence is #{test_params[:should_have_subscriber]}" do
        subscriber_present = hbx_enrollment.hbx_enrollment_members.any? { |m| m.applicant_id == primary.id }
        expect(subscriber_present).to eq test_params[:should_have_subscriber]
      end

      it "enrollment member1 presence is #{test_params[:should_have_member1]}" do
        member1_present = hbx_enrollment.hbx_enrollment_members.any? { |m| m.applicant_id == dependents.first.id }
        expect(member1_present).to eq test_params[:should_have_member1]
      end

      it "enrollment new_member presence is #{test_params[:should_have_new_member]}" do
        new_member_present = hbx_enrollment.hbx_enrollment_members.any? { |m| m.applicant_id == dependents.last.id }
        expect(new_member_present).to eq test_params[:should_have_new_member]
      end
    end

    context "when skipping both remove and add" do
      it_behaves_like "update members for hbx_enrollment", {
        remove_hbx_id: 'skip',
        add_hbx_id: 'skip',
        result_count: 2,
        should_have_subscriber: true,
        should_have_member1: true,
        should_have_new_member: false
      }
    end

    context "when removing a member but skipping add" do
      it_behaves_like "update members for hbx_enrollment", {
        remove_hbx_id: 'dependent_1_hbx_id',
        add_hbx_id: 'skip',
        result_count: 1,
        should_have_subscriber: true,
        should_have_member1: false,
        should_have_new_member: false
      }
    end

    context "when removing a member and adding a new member" do
      it_behaves_like "update members for hbx_enrollment", {
        remove_hbx_id: 'dependent_1_hbx_id',
        add_hbx_id: 'dependent_2_hbx_id',
        result_count: 2,
        should_have_subscriber: true,
        should_have_member1: false,
        should_have_new_member: true
      }
    end

    context "when only adding a new member" do
      it_behaves_like "update members for hbx_enrollment", {
        remove_hbx_id: 'skip',
        add_hbx_id: 'dependent_2_hbx_id',
        result_count: 3,
        should_have_subscriber: true,
        should_have_member1: true,
        should_have_new_member: true
      }
    end

    context "when enrollment is not found" do
      before do
        allow(subject).to receive(:enrollment_input).and_return("nonexistent_hbx_id")
        allow(subject).to receive(:person_to_remove_input).and_return('skip')
        allow(subject).to receive(:person_to_add_input).and_return('skip')
      end

      it "aborts the migration in non-test environment" do
        allow(Rails.env).to receive(:test?).and_return(false)
        expect { subject.migrate }.to raise_error(SystemExit)
      end

      it "does not abort in test environment" do
        expect { subject.migrate }.not_to raise_error
      end
    end
  end

  describe "input validation methods" do
    describe "#admin_input" do
      it "returns 'test_input' in test environment" do
        expect(subject.admin_input).to eq "test_input"
      end
    end

    describe "#confirm_input" do
      it "returns true in test environment" do
        expect(subject.confirm_input("any_input")).to eq true
      end
    end

    describe "#validated_input" do
      it "returns input from admin_input when confirmed" do
        allow(subject).to receive(:admin_input).and_return("test_value")
        allow(subject).to receive(:confirm_input).and_return(true)
        expect(subject.validated_input("test_method")).to eq "test_value"
      end
    end
  end
end
