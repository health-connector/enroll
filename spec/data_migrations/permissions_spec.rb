# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "define_permissions")

describe DefinePermissions, dbclean: :after_each do
  subject { DefinePermissions.new(given_task_name, double(:current_scope => nil))}
  let(:roles) {%w[hbx_staff hbx_read_only hbx_csr_supervisor hbx_tier3 hbx_csr_tier2 hbx_csr_tier1 developer super_admin] }

  describe 'create permissions' do
    let(:given_task_name) {':initial_hbx'}

    before do
      Person.all.delete
      person = FactoryBot.create(:person)
      FactoryBot.create(:hbx_staff_role, person: person)
      subject.initial_hbx
    end

    it "creates permissions" do
      expect(Permission.all.to_a.size).to eq(8)
      expect(Permission.all.map(&:name)).to match_array roles
    end

    context 'update permissions for hbx staff role', dbclean: :after_each do
      let(:given_task_name) {':hbx_admin_can_complete_resident_application'}

      before do
        User.all.delete
        Person.all.delete
        person = FactoryBot.create(:person)
        permission = FactoryBot.create(:permission, :hbx_staff)
        FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_staff", permission_id: permission.id)
        subject.hbx_admin_can_complete_resident_application
      end

      it "updates can_complete_resident_application to true" do
        expect(Person.all.to_a.size).to eq(1)
        expect(Person.first.hbx_staff_role.permission.can_complete_resident_application).to be true
      end
    end

    context 'update can change username and email for super admin hbx staff role', dbclean: :before_each do

      before do
        subject.hbx_admin_can_change_username_and_email
      end

      context "of an hbx super admin" do
        let(:hbx_super_admin) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "super_admin", permission_id: Permission.super_admin.id)
          end
        end

        it 'returns true' do
          expect(hbx_super_admin.hbx_staff_role.permission.can_change_username_and_email).to be true
        end
      end

      context "of an hbx tier3" do
        let(:hbx_tier3) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_tier3", permission_id: Permission.hbx_tier3.id)
          end
        end

        it 'returns true' do
          expect(hbx_tier3.hbx_staff_role.permission.can_change_username_and_email).to be true
        end
      end
    end

    context 'update can_update_pvp_eligibilities for super admin and hbx_tier3', dbclean: :before_each do
      before do
        subject.hbx_admin_can_update_pvp_eligibilities
      end

      context "of an hbx super admin" do
        let(:hbx_super_admin) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "super_admin", permission_id: Permission.super_admin.id)
          end
        end

        it 'returns true' do
          expect(hbx_super_admin.hbx_staff_role.permission.can_update_pvp_eligibilities).to be true
        end
      end

      context "of an hbx tier3" do
        let(:hbx_tier3) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_tier3", permission_id: Permission.hbx_tier3.id)
          end
        end

        it 'returns true' do
          expect(hbx_tier3.hbx_staff_role.permission.can_update_pvp_eligibilities).to be true
        end
      end
    end

    context 'update can view login history for super admin hbx staff role', dbclean: :before_each do
      let(:given_task_name) {':hbx_admin_view_login_history'}
      let(:person) { FactoryBot.create(:person) }
      let(:permission) { Permission.super_admin }
      let(:role) { FactoryBot.create(:hbx_staff_role, person: person, subrole: "super_admin", permission_id: permission.id) }

      before do
        subject.hbx_admin_view_login_history
      end

      it "updates hbx_admin_view_login_history to true" do
        expect(permission.reload.view_login_history).to be true
      end
    end

    context 'update can view login history for hbx staff role', dbclean: :before_each do
      let(:given_task_name) {':hbx_admin_can_view_notice_templates'}
      let(:person) { FactoryBot.create(:person) }
      let(:permission) { Permission.hbx_staff }
      let(:role) { FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_staff", permission_id: permission.id) }

      before do
        subject.hbx_admin_can_view_notice_templates
      end

      it "updates hbx_admin_can_view_notice_templates to true" do
        expect(permission.reload.can_view_notice_templates).to be true
      end
    end

    context 'update can edit login history for hbx staff role', dbclean: :before_each do
      let(:given_task_name) {':hbx_admin_can_edit_notice_templates'}
      let(:person) { FactoryBot.create(:person) }
      let(:permission) { Permission.hbx_staff }
      let(:role) { FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_staff", permission_id: permission.id) }

      before do
        subject.hbx_admin_can_edit_notice_templates
      end

      it "updates hbx_admin_can_edit_notice_templates to true" do
        expect(permission.reload.can_edit_notice_templates).to be true
      end
    end

    describe 'update permissions for hbx staff role to be able to view username and email' do
      let(:given_task_name) {':hbx_admin_can_add_view_username_and_email'}

      before do
        User.all.delete
        Person.all.delete
        @hbx_staff_person = FactoryBot.create(:person)
        @super_admin = FactoryBot.create(:person)
        @hbx_tier3 = FactoryBot.create(:person)
        @hbx_read_only_person = FactoryBot.create(:person)
        @hbx_csr_supervisor_person = FactoryBot.create(:person)
        @hbx_csr_tier1_person = FactoryBot.create(:person)
        @hbx_csr_tier2_person = FactoryBot.create(:person)
        FactoryBot.create(:hbx_staff_role, person: @hbx_staff_person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
        FactoryBot.create(:hbx_staff_role, person: @hbx_read_only_person, subrole: "hbx_read_only", permission_id: Permission.hbx_read_only.id)
        FactoryBot.create(:hbx_staff_role, person: @hbx_csr_supervisor_person, subrole: "hbx_csr_supervisor", permission_id: Permission.hbx_csr_supervisor.id)
        FactoryBot.create(:hbx_staff_role, person: @hbx_csr_tier1_person, subrole: "hbx_csr_tier1", permission_id: Permission.hbx_csr_tier1.id)
        FactoryBot.create(:hbx_staff_role, person: @hbx_csr_tier2_person, subrole: "hbx_csr_tier2", permission_id: Permission.hbx_csr_tier2.id)
        FactoryBot.create(:hbx_staff_role, person: @super_admin, subrole: "super_admin", permission_id: Permission.super_admin.id)
        FactoryBot.create(:hbx_staff_role, person: @hbx_tier3, subrole: "hbx_tier3", permission_id: Permission.hbx_tier3.id)
        subject.hbx_admin_can_view_username_and_email
      end

      it "updates can_view_username_and_email to true" do
        expect(Person.all.to_a.size).to eq(7)
        expect(@hbx_staff_person.hbx_staff_role.permission.can_view_username_and_email).to be true
        expect(@super_admin.hbx_staff_role.permission.can_view_username_and_email).to be true
        expect(@hbx_tier3.hbx_staff_role.permission.can_view_username_and_email).to be true
        expect(@hbx_read_only_person.hbx_staff_role.permission.can_view_username_and_email).to be false
        expect(@hbx_csr_supervisor_person.hbx_staff_role.permission.can_view_username_and_email).to be false
        expect(@hbx_csr_tier1_person.hbx_staff_role.permission.can_view_username_and_email).to be false
        expect(@hbx_csr_tier2_person.hbx_staff_role.permission.can_view_username_and_email).to be false
        #verifying that the rake task updated only the correct subroles
        expect(Permission.developer.can_add_sep).to be false
      end
    end

    describe 'update permissions for super admin role to be able to force publish' do
      let(:given_task_name) {':hbx_admin_can_force_publish'}

      before do
        User.all.delete
        Person.all.delete
      end

      context "of an hbx super admin" do
        let(:hbx_super_admin) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "super_admin", permission_id: Permission.super_admin.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_super_admin.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns true' do
            expect(hbx_super_admin.hbx_staff_role.permission.can_force_publish).to be true
          end
        end
      end

      context "of an hbx staff" do
        let(:hbx_staff) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_staff.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns false' do
            expect(hbx_staff.hbx_staff_role.permission.can_force_publish).to be false
          end
        end
      end

      context "of an hbx read only" do
        let(:hbx_read_only) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_read_only", permission_id: Permission.hbx_read_only.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_read_only.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns false' do
            expect(hbx_read_only.hbx_staff_role.permission.can_force_publish).to be false
          end
        end
      end

      context "of an hbx csr supervisor" do
        let(:hbx_csr_supervisor) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_supervisor", permission_id: Permission.hbx_csr_supervisor.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_supervisor.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns false' do
            expect(hbx_csr_supervisor.hbx_staff_role.permission.can_force_publish).to be false
          end
        end
      end

      context "of an hbx csr tier1" do
        let(:hbx_csr_tier1) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_tier1", permission_id: Permission.hbx_csr_tier1.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_tier1.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns false' do
            expect(hbx_csr_tier1.hbx_staff_role.permission.can_force_publish).to be false
          end
        end
      end

      context "of an hbx csr tier2" do
        let(:hbx_csr_tier2) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_tier2", permission_id: Permission.hbx_csr_tier2.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_tier2.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns false' do
            expect(hbx_csr_tier2.hbx_staff_role.permission.can_force_publish).to be false
          end
        end
      end

      context "of an hbx tier3" do
        let(:hbx_tier3) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_tier3", permission_id: Permission.hbx_tier3.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_tier3.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns true' do
            expect(hbx_tier3.hbx_staff_role.permission.can_force_publish).to be true
          end
        end
      end

      context "of an hbx staff" do
        let(:hbx_staff) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_staff.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns false' do
            expect(hbx_staff.hbx_staff_role.permission.can_force_publish).to be false
          end
        end
      end

      context "of an hbx staff" do
        let(:developer) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "developer", permission_id: Permission.developer.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(developer.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns false' do
            expect(developer.hbx_staff_role.permission.can_force_publish).to be false
          end
        end
      end
    end

    describe 'update permissions for super admin role to be able to change FEIN' do
      let(:given_task_name) {':hbx_admin_can_change_fein'}

      before do
        User.all.delete
        Person.all.delete
      end

      context "of an hbx super admin" do
        let(:hbx_super_admin) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "super_admin", permission_id: Permission.super_admin.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_super_admin.hbx_staff_role.permission.can_change_fein).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_change_fein
          end

          it 'returns true' do
            expect(hbx_super_admin.hbx_staff_role.permission.can_change_fein).to be true
          end
        end
      end

      context "of an hbx staff" do
        let(:hbx_staff) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_staff.hbx_staff_role.permission.can_change_fein).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_change_fein
          end

          it 'returns false' do
            expect(hbx_staff.hbx_staff_role.permission.can_change_fein).to be false
          end
        end
      end

      context "of an hbx read only" do
        let(:hbx_read_only) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_read_only", permission_id: Permission.hbx_read_only.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_read_only.hbx_staff_role.permission.can_change_fein).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_change_fein
          end

          it 'returns false' do
            expect(hbx_read_only.hbx_staff_role.permission.can_change_fein).to be false
          end
        end
      end

      context "of an hbx csr supervisor" do
        let(:hbx_csr_supervisor) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_supervisor", permission_id: Permission.hbx_csr_supervisor.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_supervisor.hbx_staff_role.permission.can_change_fein).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_change_fein
          end

          it 'returns false' do
            expect(hbx_csr_supervisor.hbx_staff_role.permission.can_change_fein).to be false
          end
        end
      end

      context "of an hbx csr tier1" do
        let(:hbx_csr_tier1) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_tier1", permission_id: Permission.hbx_csr_tier1.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_tier1.hbx_staff_role.permission.can_change_fein).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_change_fein
          end

          it 'returns false' do
            expect(hbx_csr_tier1.hbx_staff_role.permission.can_change_fein).to be false
          end
        end
      end

      context "of an hbx csr tier2" do
        let(:hbx_csr_tier2) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_tier2", permission_id: Permission.hbx_csr_tier2.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_tier2.hbx_staff_role.permission.can_change_fein).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_change_fein
          end

          it 'returns false' do
            expect(hbx_csr_tier2.hbx_staff_role.permission.can_change_fein).to be false
          end
        end
      end

      context "of an hbx tier3" do
        let(:hbx_tier3) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_tier3", permission_id: Permission.hbx_tier3.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_tier3.hbx_staff_role.permission.can_change_fein).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_change_fein
          end

          it 'returns false' do
            expect(hbx_tier3.hbx_staff_role.permission.can_change_fein).to be true
          end
        end
      end

      context "of an hbx developer" do
        let(:developer) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "developer", permission_id: Permission.developer.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(developer.hbx_staff_role.permission.can_change_fein).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_change_fein
          end

          it 'returns false' do
            expect(developer.hbx_staff_role.permission.can_change_fein).to be false
          end
        end
      end
    end

    describe 'update permissions for hbx staff role to add sep' do
      let(:given_task_name) {':hbx_admin_can_add_sep'}

      before do
        User.all.delete
        Person.all.delete
        @hbx_staff_person = FactoryBot.create(:person)
        @super_admin = FactoryBot.create(:person)
        @hbx_tier3 = FactoryBot.create(:person)
        @hbx_read_only_person = FactoryBot.create(:person)
        @hbx_csr_supervisor_person = FactoryBot.create(:person)
        FactoryBot.create(:hbx_staff_role, person: @hbx_staff_person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
        FactoryBot.create(:hbx_staff_role, person: @hbx_read_only_person, subrole: "hbx_read_only", permission_id: Permission.hbx_read_only.id)
        FactoryBot.create(:hbx_staff_role, person: @hbx_csr_supervisor_person, subrole: "hbx_csr_supervisor", permission_id: Permission.hbx_csr_supervisor.id)
        FactoryBot.create(:hbx_staff_role, person: @super_admin, subrole: "super_admin", permission_id: Permission.super_admin.id)
        FactoryBot.create(:hbx_staff_role, person: @hbx_tier3, subrole: "hbx_tier3", permission_id: Permission.hbx_tier3.id)
        subject.hbx_admin_can_add_sep
      end

      it "updates can_complete_resident_application to true" do
        expect(Person.all.to_a.size).to eq(5)
        expect(@hbx_staff_person.hbx_staff_role.permission.can_add_sep).to be true
        expect(@super_admin.hbx_staff_role.permission.can_add_sep).to be true
        expect(@hbx_tier3.hbx_staff_role.permission.can_add_sep).to be true
        expect(@hbx_read_only_person.hbx_staff_role.permission.can_add_sep).to be false
        expect(@hbx_csr_supervisor_person.hbx_staff_role.permission.can_add_sep).to be false
        #verifying that the rake task updated only the correct subroles
        expect(Permission.hbx_csr_tier1.can_add_sep).to be false
        expect(Permission.hbx_csr_tier2.can_add_sep).to be false
        expect(Permission.developer.can_add_sep).to be false
      end
    end

    describe 'update permissions for hbx tier3 can extend open enrollment' do
      let(:given_task_name) {':hbx_admin_can_extend_open_enrollment'}
      before do
        User.all.delete
        Person.all.delete
      end
      context "of an hbx tier3" do
        let(:hbx_tier3) do
          FactoryBot.create(:person, :with_hbx_staff_role).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_tier3", permission_id: Permission.hbx_tier3.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_tier3.hbx_staff_role.permission.can_extend_open_enrollment).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_extend_open_enrollment
          end

          it 'returns true' do
            expect(hbx_tier3.hbx_staff_role.permission.can_extend_open_enrollment).to be true
          end
        end
      end
    end

    describe 'update permissions for super admin role to be able to create benefit application' do
      let(:given_task_name) {':hbx_admin_can_create_benefit_application'}

      before do
        User.all.delete
        Person.all.delete
      end

      context "of an hbx super admin" do
        let(:hbx_super_admin) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "super_admin", permission_id: Permission.super_admin.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_super_admin.hbx_staff_role.permission.can_create_benefit_application).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_create_benefit_application
          end

          it 'returns true' do
            expect(hbx_super_admin.hbx_staff_role.permission.can_create_benefit_application).to be true
          end
        end
      end

      context "of an hbx staff" do
        let(:hbx_staff) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_staff.hbx_staff_role.permission.can_create_benefit_application).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_create_benefit_application
          end

          it 'returns false' do
            expect(hbx_staff.hbx_staff_role.permission.can_create_benefit_application).to be false
          end
        end
      end

      context "of an hbx read only" do
        let(:hbx_read_only) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_read_only", permission_id: Permission.hbx_read_only.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_read_only.hbx_staff_role.permission.can_create_benefit_application).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_create_benefit_application
          end

          it 'returns false' do
            expect(hbx_read_only.hbx_staff_role.permission.can_create_benefit_application).to be false
          end
        end
      end

      context "of an hbx csr supervisor" do
        let(:hbx_csr_supervisor) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_supervisor", permission_id: Permission.hbx_csr_supervisor.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_supervisor.hbx_staff_role.permission.can_create_benefit_application).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_create_benefit_application
          end

          it 'returns false' do
            expect(hbx_csr_supervisor.hbx_staff_role.permission.can_create_benefit_application).to be false
          end
        end
      end

      context "of an hbx csr tier1" do
        let(:hbx_csr_tier1) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_tier1", permission_id: Permission.hbx_csr_tier1.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_tier1.hbx_staff_role.permission.can_create_benefit_application).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_create_benefit_application
          end

          it 'returns false' do
            expect(hbx_csr_tier1.hbx_staff_role.permission.can_create_benefit_application).to be false
          end
        end
      end

      context "of an hbx csr tier2" do
        let(:hbx_csr_tier2) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_tier2", permission_id: Permission.hbx_csr_tier2.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_tier2.hbx_staff_role.permission.can_create_benefit_application).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_create_benefit_application
          end

          it 'returns false' do
            expect(hbx_csr_tier2.hbx_staff_role.permission.can_create_benefit_application).to be false
          end
        end
      end

      context "of an hbx tier3" do
        let(:hbx_tier3) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_tier3", permission_id: Permission.hbx_tier3.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_tier3.hbx_staff_role.permission.can_create_benefit_application).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_create_benefit_application
          end

          it 'returns true' do
            expect(hbx_tier3.hbx_staff_role.permission.can_create_benefit_application).to be true
          end
        end
      end

      context "of an hbx staff" do
        let(:hbx_staff) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_staff.hbx_staff_role.permission.can_create_benefit_application).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_create_benefit_application
          end

          it 'returns false' do
            expect(hbx_staff.hbx_staff_role.permission.can_create_benefit_application).to be false
          end
        end
      end

      context "of a developer" do
        let(:developer) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "developer", permission_id: Permission.developer.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(developer.hbx_staff_role.permission.can_create_benefit_application).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_create_benefit_application
          end

          it 'returns false' do
            expect(developer.hbx_staff_role.permission.can_create_benefit_application).to be false
          end
        end
      end
    end

    describe 'update permissions for staff role to update enrollment end date and to reinstate enrollment' do
      let(:given_task_name) {':hbx_admin_can_update_enrollment_end_date_or_reinstate'}

      before do
        User.all.delete
        Person.all.delete
      end

      context "of an hbx super admin" do
        let(:hbx_super_admin) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "super_admin", permission_id: Permission.super_admin.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_super_admin.hbx_staff_role.permission.can_update_enrollment_end_date).to be false
          expect(hbx_super_admin.hbx_staff_role.permission.can_reinstate_enrollment).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_update_enrollment_end_date_or_reinstate
          end

          it 'returns true' do
            expect(hbx_super_admin.hbx_staff_role.permission.can_update_enrollment_end_date).to be true
            expect(hbx_super_admin.hbx_staff_role.permission.can_reinstate_enrollment).to be true
          end
        end
      end

      context "of an hbx staff" do
        let(:hbx_staff) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_staff.hbx_staff_role.permission.can_update_enrollment_end_date).to be false
          expect(hbx_staff.hbx_staff_role.permission.can_reinstate_enrollment).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_update_enrollment_end_date_or_reinstate
          end

          it 'returns false' do
            expect(hbx_staff.hbx_staff_role.permission.can_update_enrollment_end_date).to be false
            expect(hbx_staff.hbx_staff_role.permission.can_reinstate_enrollment).to be false
          end
        end
      end

      context "of an hbx read only" do
        let(:hbx_read_only) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_read_only", permission_id: Permission.hbx_read_only.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_read_only.hbx_staff_role.permission.can_update_enrollment_end_date).to be false
          expect(hbx_read_only.hbx_staff_role.permission.can_reinstate_enrollment).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_update_enrollment_end_date_or_reinstate
          end

          it 'returns false' do
            expect(hbx_read_only.hbx_staff_role.permission.can_update_enrollment_end_date).to be false
            expect(hbx_read_only.hbx_staff_role.permission.can_reinstate_enrollment).to be false
          end
        end
      end

      context "of an hbx csr supervisor" do
        let(:hbx_csr_supervisor) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_supervisor", permission_id: Permission.hbx_csr_supervisor.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_supervisor.hbx_staff_role.permission.can_reinstate_enrollment).to be false
          expect(hbx_csr_supervisor.hbx_staff_role.permission.can_update_enrollment_end_date).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_update_enrollment_end_date_or_reinstate
          end

          it 'returns false' do
            expect(hbx_csr_supervisor.hbx_staff_role.permission.can_reinstate_enrollment).to be false
            expect(hbx_csr_supervisor.hbx_staff_role.permission.can_update_enrollment_end_date).to be false
          end
        end
      end

      context "of an hbx csr tier1" do
        let(:hbx_csr_tier1) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_tier1", permission_id: Permission.hbx_csr_tier1.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_tier1.hbx_staff_role.permission.can_reinstate_enrollment).to be false
          expect(hbx_csr_tier1.hbx_staff_role.permission.can_update_enrollment_end_date).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_update_enrollment_end_date_or_reinstate
          end

          it 'returns false' do
            expect(hbx_csr_tier1.hbx_staff_role.permission.can_update_enrollment_end_date).to be false
            expect(hbx_csr_tier1.hbx_staff_role.permission.can_reinstate_enrollment).to be false
          end
        end
      end

      context "of an hbx csr tier2" do
        let(:hbx_csr_tier2) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_tier2", permission_id: Permission.hbx_csr_tier2.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_tier2.hbx_staff_role.permission.can_update_enrollment_end_date).to be false
          expect(hbx_csr_tier2.hbx_staff_role.permission.can_reinstate_enrollment).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_update_enrollment_end_date_or_reinstate
          end

          it 'returns false' do
            expect(hbx_csr_tier2.hbx_staff_role.permission.can_update_enrollment_end_date).to be false
            expect(hbx_csr_tier2.hbx_staff_role.permission.can_reinstate_enrollment).to be false
          end
        end
      end

      context "of an hbx tier3" do
        let(:hbx_tier3) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_tier3", permission_id: Permission.hbx_tier3.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_tier3.hbx_staff_role.permission.can_update_enrollment_end_date).to be false
          expect(hbx_tier3.hbx_staff_role.permission.can_reinstate_enrollment).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_update_enrollment_end_date_or_reinstate
          end

          it 'returns true' do
            expect(hbx_tier3.hbx_staff_role.permission.can_update_enrollment_end_date).to be true
            expect(hbx_tier3.hbx_staff_role.permission.can_reinstate_enrollment).to be true
          end
        end
      end

      context "of a developer" do
        let(:developer) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "developer", permission_id: Permission.developer.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(developer.hbx_staff_role.permission.can_update_enrollment_end_date).to be false
          expect(developer.hbx_staff_role.permission.can_reinstate_enrollment).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_update_enrollment_end_date_or_reinstate
          end

          it 'returns false' do
            expect(developer.hbx_staff_role.permission.can_update_enrollment_end_date).to be false
            expect(developer.hbx_staff_role.permission.can_reinstate_enrollment).to be false
          end
        end
      end
    end

    describe 'update permissions for super admin role to be able to modify benefit application from employers index' do
      let(:given_task_name) {':hbx_admin_can_modify_plan_year'}

      before do
        User.all.delete
        Person.all.delete
      end

      context "of an hbx super admin" do
        let(:hbx_super_admin) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "super_admin", permission_id: Permission.super_admin.id)
          end
        end

        before do
          subject.hbx_admin_can_modify_plan_year
        end

        it 'returns true' do
          expect(hbx_super_admin.hbx_staff_role.permission.can_modify_plan_year).to be true
        end
      end

      context "of an hbx staff" do
        let(:hbx_staff) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_staff.hbx_staff_role.permission.can_modify_plan_year).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_modify_plan_year
          end

          it 'returns false' do
            expect(hbx_staff.hbx_staff_role.permission.can_modify_plan_year).to be false
          end
        end
      end

      context "of an hbx read only" do
        let(:hbx_read_only) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_read_only", permission_id: Permission.hbx_read_only.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_read_only.hbx_staff_role.permission.can_modify_plan_year).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_modify_plan_year
          end

          it 'returns false' do
            expect(hbx_read_only.hbx_staff_role.permission.can_modify_plan_year).to be false
          end
        end
      end

      context "of an hbx csr supervisor" do
        let(:hbx_csr_supervisor) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_supervisor", permission_id: Permission.hbx_csr_supervisor.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_supervisor.hbx_staff_role.permission.can_modify_plan_year).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_modify_plan_year
          end

          it 'returns false' do
            expect(hbx_csr_supervisor.hbx_staff_role.permission.can_modify_plan_year).to be false
          end
        end
      end

      context "of an hbx csr tier1" do
        let(:hbx_csr_tier1) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_tier1", permission_id: Permission.hbx_csr_tier1.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_tier1.hbx_staff_role.permission.can_modify_plan_year).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_modify_plan_year
          end

          it 'returns false' do
            expect(hbx_csr_tier1.hbx_staff_role.permission.can_modify_plan_year).to be false
          end
        end
      end

      context "of an hbx csr tier2" do
        let(:hbx_csr_tier2) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_csr_tier2", permission_id: Permission.hbx_csr_tier2.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_tier2.hbx_staff_role.permission.can_modify_plan_year).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_modify_plan_year
          end

          it 'returns false' do
            expect(hbx_csr_tier2.hbx_staff_role.permission.can_modify_plan_year).to be false
          end
        end
      end

      context "of an hbx tier3" do
        let(:hbx_tier3) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "hbx_tier3", permission_id: Permission.hbx_tier3.id)
          end
        end

        before do
          subject.hbx_admin_can_modify_plan_year
        end

        it 'returns true' do
          expect(hbx_tier3.hbx_staff_role.permission.can_modify_plan_year).to be true
        end
      end

      context "of a developer" do
        let(:developer) do
          FactoryBot.create(:person).tap do |person|
            FactoryBot.create(:hbx_staff_role, person: person, subrole: "developer", permission_id: Permission.developer.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(developer.hbx_staff_role.permission.can_modify_plan_year).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_modify_plan_year
          end

          it 'returns false' do
            expect(developer.hbx_staff_role.permission.can_modify_plan_year).to be false
          end
        end
      end
    end
  end

  describe 'build test roles', dbclean: :after_each do
    let(:given_task_name) {':build_test_roles'}
    before do
      User.all.delete
      Person.all.delete
      allow(Permission).to receive_message_chain('hbx_staff.id'){FactoryBot.create(:permission, :hbx_staff).id}
      allow(Permission).to receive_message_chain('hbx_read_only.id'){FactoryBot.create(:permission, :hbx_read_only).id}
      allow(Permission).to receive_message_chain('hbx_csr_supervisor.id'){FactoryBot.create(:permission, :hbx_csr_supervisor).id}
      allow(Permission).to receive_message_chain('hbx_csr_tier2.id'){FactoryBot.create(:permission,  :hbx_csr_tier2).id}
      allow(Permission).to receive_message_chain('hbx_csr_tier1.id'){FactoryBot.create(:permission,  :hbx_csr_tier1).id}
      allow(Permission).to receive_message_chain('developer.id'){FactoryBot.create(:permission,  :developer).id}
      allow(Permission).to receive_message_chain('hbx_tier3.id'){FactoryBot.create(:permission,  :hbx_tier3).id}
      allow(Permission).to receive_message_chain('super_admin.id'){FactoryBot.create(:permission,  :super_admin).id}
      subject.build_test_roles
    end
    it "creates permissions" do
      expect(User.all.to_a.size).to eq(8)
      expect(Person.all.to_a.size).to eq(8)
      expect(Person.all.to_a.map{|p| p.hbx_staff_role.subrole}).to match_array roles
    end
  end
end
