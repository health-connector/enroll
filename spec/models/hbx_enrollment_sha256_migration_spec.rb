# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Enrollment Signature SHA256 Migration', type: :model do

  # Enrollment signatures are generated for ANY enrollment regardless of role type
  # (consumer_role for IVL, employee_role for SHOP, etc.)
  # The signature is based on applicant_id of family members, not person role

  let(:person_consumer) { FactoryBot.create(:person, :with_consumer_role, :with_family) }
  let(:person_employee) { FactoryBot.create(:person, :with_employee_role, :with_family) }
  let(:family_consumer) { person_consumer.primary_family }
  let(:family_employee) { person_employee.primary_family }
  let(:household_consumer) { family_consumer.active_household }
  let(:household_employee) { family_employee.active_household }
  let(:plan) { FactoryBot.create(:plan) }
  let(:shop_plan) { FactoryBot.create(:plan) }

  describe 'generate_hbx_signature' do
    context 'with subscriber in IVL (consumer role) enrollment' do
      it 'generates SHA256 signature for new individual market enrollments' do
        enrollment = HbxEnrollment.new(
          kind: 'individual',
          plan: plan,
          effective_on: TimeKeeper.date_of_record,
          household: household_consumer
        )

        # Add a subscriber
        member = HbxEnrollmentMember.new(applicant_id: person_consumer.id, is_subscriber: true)
        enrollment.hbx_enrollment_members << member

        enrollment.generate_hbx_signature

        expected_sig = Digest::SHA256.hexdigest(person_consumer.id.to_s)
        expect(enrollment.enrollment_signature).to eq(expected_sig)
        expect(enrollment.enrollment_signature.length).to eq(64) # SHA256 hex is 64 chars, MD5 is 32
      end
    end

    context 'with subscriber in SHOP (employee role) enrollment' do
      it 'generates SHA256 signature for new employer-sponsored enrollments' do
        enrollment = HbxEnrollment.new(
          kind: 'employer_sponsored',
          plan: shop_plan,
          effective_on: TimeKeeper.date_of_record,
          household: household_employee
        )

        # Add a subscriber (same logic - applicant_id based, role-agnostic)
        member = HbxEnrollmentMember.new(applicant_id: person_employee.id, is_subscriber: true)
        enrollment.hbx_enrollment_members << member

        enrollment.generate_hbx_signature

        expected_sig = Digest::SHA256.hexdigest(person_employee.id.to_s)
        expect(enrollment.enrollment_signature).to eq(expected_sig)
        expect(enrollment.enrollment_signature.length).to eq(64)
      end
    end

    context 'without subscriber (fallback to sorted applicant_ids) - role agnostic' do
      it 'generates SHA256 signature from sorted applicant IDs for any market/role type' do
        enrollment = HbxEnrollment.new(
          kind: 'individual',
          plan: plan,
          effective_on: TimeKeeper.date_of_record,
          household: household_consumer
        )

        # Add multiple members without marking subscriber
        member1 = HbxEnrollmentMember.new(applicant_id: person_consumer.id, is_subscriber: false)
        enrollment.hbx_enrollment_members << member1

        enrollment.generate_hbx_signature

        applicant_ids = enrollment.hbx_enrollment_members.map(&:applicant_id)
        expected_sig = Digest::SHA256.hexdigest(applicant_ids.sort.map(&:to_s).join)
        expect(enrollment.enrollment_signature).to eq(expected_sig)
        expect(enrollment.enrollment_signature.length).to eq(64)
      end
    end

    it 'produces different hash than MD5 for the same input' do
      enrollment = HbxEnrollment.new(
        kind: 'individual',
        plan: plan,
        effective_on: TimeKeeper.date_of_record,
        household: household_consumer
      )

      member = HbxEnrollmentMember.new(applicant_id: person_consumer.id, is_subscriber: true)
      enrollment.hbx_enrollment_members << member

      enrollment.generate_hbx_signature
      sha256_sig = enrollment.enrollment_signature

      md5_sig = Digest::MD5.hexdigest(person_consumer.id.to_s)

      expect(sha256_sig).not_to eq(md5_sig)
      expect(sha256_sig.length).to eq(64)
      expect(md5_sig.length).to eq(32)
    end

  end

  describe 'MigrateEnrollmentSignatureToSha256' do
    let(:enrollment_consumer) do
      enrollment = HbxEnrollment.create!(
        kind: 'individual',
        plan: plan,
        effective_on: TimeKeeper.date_of_record,
        household: household_consumer
      )
      member = HbxEnrollmentMember.new(applicant_id: person_consumer.id, is_subscriber: true)
      enrollment.hbx_enrollment_members << member

      # Manually set MD5 signature to simulate old data
      md5_sig = Digest::MD5.hexdigest(person_consumer.id.to_s)
      enrollment.update_attribute(:enrollment_signature, md5_sig)
      enrollment
    end

    let(:enrollment_shop) do
      enrollment = HbxEnrollment.create!(
        kind: 'employer_sponsored',
        plan: shop_plan,
        effective_on: TimeKeeper.date_of_record,
        household: household_employee
      )
      member = HbxEnrollmentMember.new(applicant_id: person_employee.id, is_subscriber: true)
      enrollment.hbx_enrollment_members << member

      # Manually set MD5 signature to simulate old data
      md5_sig = Digest::MD5.hexdigest(person_employee.id.to_s)
      enrollment.update_attribute(:enrollment_signature, md5_sig)
      enrollment
    end

    it 'backfills MD5 signatures to SHA256 for all role types' do
      # Verify it starts with MD5 for both
      expect(enrollment_consumer.reload.enrollment_signature.length).to eq(32)
      expect(enrollment_shop.reload.enrollment_signature.length).to eq(32)
      old_consumer_signature = enrollment_consumer.enrollment_signature
      old_shop_signature = enrollment_shop.enrollment_signature

      # Run migration with actual update
      ENV['DRYRUN'] = 'false'
      migrator = MigrateEnrollmentSignatureToSha256.new(:migrate_enrollment_signature_to_sha256, Rake::Application.new)
      migrator.migrate

      # Verify both were updated to SHA256
      expect(enrollment_consumer.reload.enrollment_signature.length).to eq(64)
      expect(enrollment_shop.reload.enrollment_signature.length).to eq(64)
      expect(enrollment_consumer.enrollment_signature).not_to eq(old_consumer_signature)
      expect(enrollment_shop.enrollment_signature).not_to eq(old_shop_signature)
    end

    it 'does not update signatures that are already SHA256' do
      # Create enrollments with SHA256 signatures
      sha256_sig_consumer = Digest::SHA256.hexdigest(person_consumer.id.to_s)
      sha256_sig_shop = Digest::SHA256.hexdigest(person_employee.id.to_s)

      enrollment_consumer.update_attribute(:enrollment_signature, sha256_sig_consumer)
      enrollment_shop.update_attribute(:enrollment_signature, sha256_sig_shop)

      # Run migration
      ENV['DRYRUN'] = 'false'
      migrator = MigrateEnrollmentSignatureToSha256.new(:migrate_enrollment_signature_to_sha256, Rake::Application.new)
      migrator.migrate

      # Verify signatures unchanged
      expect(enrollment_consumer.reload.enrollment_signature).to eq(sha256_sig_consumer)
      expect(enrollment_shop.reload.enrollment_signature).to eq(sha256_sig_shop)
    end

    it 'handles enrollments without signatures' do
      enrollment_no_sig = HbxEnrollment.create!(
        kind: 'individual',
        plan: plan,
        effective_on: TimeKeeper.date_of_record,
        household: household_consumer,
        enrollment_signature: nil
      )

      ENV['DRYRUN'] = 'false'
      migrator = MigrateEnrollmentSignatureToSha256.new(:migrate_enrollment_signature_to_sha256, Rake::Application.new)
      expect { migrator.migrate }.not_to raise_error

      expect(enrollment_no_sig.reload.enrollment_signature).to be_nil
    end
  end

  describe 'same_signatures comparison with new SHA256 hashes' do
    let(:person2_consumer) { FactoryBot.create(:person, :with_consumer_role, :with_family) }
    let(:family2_consumer) { person2_consumer.primary_family }
    let(:household2_consumer) { family2_consumer.active_household }

    it 'correctly identifies matching signatures with SHA256 across any role type' do
      enrollment1 = HbxEnrollment.create!(
        kind: 'individual',
        plan: plan,
        effective_on: TimeKeeper.date_of_record,
        household: household_consumer
      )
      member1 = HbxEnrollmentMember.new(applicant_id: person_consumer.id, is_subscriber: true)
      enrollment1.hbx_enrollment_members << member1
      enrollment1.generate_hbx_signature

      enrollment2 = HbxEnrollment.create!(
        kind: 'individual',
        plan: plan,
        effective_on: TimeKeeper.date_of_record,
        household: household2_consumer
      )
      member2 = HbxEnrollmentMember.new(applicant_id: person_consumer.id, is_subscriber: true)
      enrollment2.hbx_enrollment_members << member2
      enrollment2.generate_hbx_signature

      # Both should have same SHA256 signature (same subscriber)
      expect(enrollment1.enrollment_signature).to eq(enrollment2.enrollment_signature)
      expect(enrollment1.enrollment_signature.length).to eq(64)
    end

    it 'correctly identifies different signatures with SHA256 across role types' do
      enrollment_ivl = HbxEnrollment.create!(
        kind: 'individual',
        plan: plan,
        effective_on: TimeKeeper.date_of_record,
        household: household_consumer
      )
      member_ivl = HbxEnrollmentMember.new(applicant_id: person_consumer.id, is_subscriber: true)
      enrollment_ivl.hbx_enrollment_members << member_ivl
      enrollment_ivl.generate_hbx_signature

      enrollment_shop = HbxEnrollment.create!(
        kind: 'employer_sponsored',
        plan: shop_plan,
        effective_on: TimeKeeper.date_of_record,
        household: household_employee
      )
      member_shop = HbxEnrollmentMember.new(applicant_id: person_employee.id, is_subscriber: true)
      enrollment_shop.hbx_enrollment_members << member_shop
      enrollment_shop.generate_hbx_signature

      # Should have different SHA256 signatures (different subscribers)
      # Note: signature is based on applicant_id (person ID), not on role type
      expect(enrollment_ivl.enrollment_signature).not_to eq(enrollment_shop.enrollment_signature)
      expect(enrollment_ivl.enrollment_signature.length).to eq(64)
      expect(enrollment_shop.enrollment_signature.length).to eq(64)
    end
  end
end