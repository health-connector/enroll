# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IdentityVerificationPolicy, type: :policy do
  subject { IdentityVerificationPolicy }

  let(:person) { FactoryBot.create(:person, :with_family) }
  let(:family) { person.primary_family }
  let(:user) { FactoryBot.create(:user, person: person) }

  permissions :new?, :create?, :show? do
    context "when user is the primary family member" do
      before do
        # Mock the family policy to return true for show access
        family_policy = instance_double(FamilyPolicy)
        allow(FamilyPolicy).to receive(:new).with(user, family).and_return(family_policy)
        allow(family_policy).to receive(:show?).and_return(true)
      end

      it "grants access" do
        expect(subject).to permit(user, person)
      end
    end

    context "when user is an IVL user (same person)" do
      let(:ivl_person) { FactoryBot.create(:person, :with_consumer_role) }
      let(:ivl_user) { FactoryBot.create(:user, person: ivl_person) }
      
      it "grants access to their own identity verification" do
        expect(subject).to permit(ivl_user, ivl_person)
      end
    end

    context "when user is not the primary family member" do
      let(:other_user) { FactoryBot.create(:user) }
      
      before do
        # Mock the family policy to return false for show access
        family_policy = instance_double(FamilyPolicy)
        allow(FamilyPolicy).to receive(:new).with(other_user, family).and_return(family_policy)
        allow(family_policy).to receive(:show?).and_return(false)
      end
      
      it "denies access" do
        expect(subject).not_to permit(other_user, person)
      end
    end

    context "when user is an HBX staff with appropriate permissions" do
      let(:hbx_person) { FactoryBot.create(:person, :with_hbx_staff_role) }
      let(:hbx_user) { FactoryBot.create(:user, :hbx_staff, person: hbx_person) }
      
      before do
        # Mock permission for HBX staff with all required methods
        permission_mock = double(modify_family: true, can_update_ssn: true)
        allow(hbx_person.hbx_staff_role).to receive(:permission).and_return(permission_mock)
      end

      it "grants access" do
        expect(subject).to permit(hbx_user, person)
      end
    end

    context "when person has no family" do
      let(:person_without_family) { FactoryBot.create(:person) }
      
      it "denies access" do
        expect(subject).not_to permit(user, person_without_family)
      end
    end
  end

  permissions :update? do
    context "when regular user tries update (should be denied since update is admin-only)" do
      before do
        # Even with family policy access, regular users cannot do update (override)
        family_policy = instance_double(FamilyPolicy)
        allow(FamilyPolicy).to receive(:new).with(user, family).and_return(family_policy)
        allow(family_policy).to receive(:show?).and_return(true)
        allow(family_policy).to receive(:updateable?).and_return(true)
      end

      it "denies access since update is admin-only" do
        expect(subject).not_to permit(user, person)
      end
    end

    context "when user has verification override permissions" do
      let(:admin_person) { FactoryBot.create(:person, :with_hbx_staff_role) }
      let(:admin_user) { FactoryBot.create(:user, :hbx_staff, person: admin_person) }
      
      before do
        # Mock the permission object
        permission = double(can_update_ssn: true)
        allow(admin_person.hbx_staff_role).to receive(:permission).and_return(permission)
        
        # Mock family policy
        family_policy = instance_double(FamilyPolicy)
        allow(FamilyPolicy).to receive(:new).with(admin_user, family).and_return(family_policy)
        allow(family_policy).to receive(:show?).and_return(true)
        allow(family_policy).to receive(:updateable?).and_return(false)
      end

      it "grants access" do
        expect(subject).to permit(admin_user, person)
      end
    end

    context "when user lacks override permissions" do
      let(:regular_user) { FactoryBot.create(:user) }
      
      before do
        # Mock family policy to deny access
        family_policy = instance_double(FamilyPolicy)
        allow(FamilyPolicy).to receive(:new).with(regular_user, family).and_return(family_policy)
        allow(family_policy).to receive(:show?).and_return(false)
      end
      
      it "denies access" do
        expect(subject).not_to permit(regular_user, person)
      end
    end
  end
end
