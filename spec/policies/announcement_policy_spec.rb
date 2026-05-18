# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnnouncementPolicy, type: :policy do
  let(:user) { FactoryBot.create(:user) }
  let(:person) { FactoryBot.create(:person, user: user) }
  let(:announcement) { FactoryBot.create(:announcement) }

  subject { described_class.new(user, announcement) }

  before do
    allow(user).to receive(:person).and_return(person)
  end

  describe '#index?' do
    context 'when user has hbx_staff_role' do
      before do
        FactoryBot.create(:hbx_staff_role, person: person)
      end

      it 'permits access' do
        expect(subject.index?).to be_truthy
      end
    end

    context 'when user does not have hbx_staff_role' do
      it 'denies access' do
        expect(subject.index?).to be_falsy
      end
    end
  end

  describe '#create?' do
    context 'when user has hbx_staff_role with modify_admin_tabs permission' do
      let(:permission) { FactoryBot.create(:permission, modify_admin_tabs: true) }
      let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person) }

      before do
        allow(hbx_staff_role).to receive(:permission).and_return(permission)
      end

      it 'permits access' do
        expect(subject.create?).to be_truthy
      end
    end

    context 'when user has hbx_staff_role without modify_admin_tabs permission' do
      let(:permission) { FactoryBot.create(:permission, modify_admin_tabs: false) }
      let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person) }

      before do
        allow(hbx_staff_role).to receive(:permission).and_return(permission)
      end

      it 'denies access' do
        expect(subject.create?).to be_falsy
      end
    end

    context 'when user does not have hbx_staff_role' do
      it 'denies access' do
        expect(subject.create?).to be_falsy
      end
    end
  end

  describe '#destroy?' do
    context 'when user has hbx_staff_role with modify_admin_tabs permission' do
      let(:permission) { FactoryBot.create(:permission, modify_admin_tabs: true) }
      let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person) }

      before do
        allow(hbx_staff_role).to receive(:permission).and_return(permission)
      end

      it 'permits access' do
        expect(subject.destroy?).to be_truthy
      end
    end

    context 'when user has hbx_staff_role without modify_admin_tabs permission' do
      let(:permission) { FactoryBot.create(:permission, modify_admin_tabs: false) }
      let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person) }

      before do
        allow(hbx_staff_role).to receive(:permission).and_return(permission)
      end

      it 'denies access' do
        expect(subject.destroy?).to be_falsy
      end
    end

    context 'when user does not have hbx_staff_role' do
      it 'denies access' do
        expect(subject.destroy?).to be_falsy
      end
    end
  end

  describe '#dismiss?' do
    context 'when user has csr_role' do
      before do
        FactoryBot.create(:csr_role, person: person)
      end

      it 'permits access' do
        expect(subject.dismiss?).to be_truthy
      end
    end

    context 'when user has assister_role' do
      before do
        FactoryBot.create(:assister_role, person: person)
      end

      it 'permits access' do
        expect(subject.dismiss?).to be_truthy
      end
    end

    context 'when user has hbx_staff_role' do
      before do
        FactoryBot.create(:hbx_staff_role, person: person)
      end

      it 'permits access' do
        expect(subject.dismiss?).to be_truthy
      end
    end

    context 'when user has active broker_role' do
      before do
        broker_role = FactoryBot.create(:broker_role, person: person)
        allow(broker_role).to receive(:active?).and_return(true)
      end

      it 'permits access' do
        expect(subject.dismiss?).to be_truthy
      end
    end

    context 'when user has inactive broker_role' do
      before do
        broker_role = FactoryBot.create(:broker_role, person: person)
        allow(broker_role).to receive(:active?).and_return(false)
      end

      it 'denies access' do
        expect(subject.dismiss?).to be_falsy
      end
    end

    context 'when user has active broker_agency_staff_roles' do
      before do
        allow(person).to receive(:broker_agency_staff_roles).and_return(
          double('BrokerAgencyStaffRoles', active: double('ActiveRoles', present?: true))
        )
      end

      it 'permits access' do
        expect(subject.dismiss?).to be_truthy
      end
    end

    context 'when user has active employer staff role' do
      before do
        allow(person).to receive(:has_active_employer_staff_role?).and_return(true)
      end

      it 'permits access' do
        expect(subject.dismiss?).to be_truthy
      end
    end

    context 'when user has employee_roles' do
      before do
        allow(person).to receive(:employee_roles).and_return([double('EmployeeRole')])
      end

      it 'permits access' do
        expect(subject.dismiss?).to be_truthy
      end
    end

    context 'when user has no qualifying roles' do
      it 'denies access' do
        expect(subject.dismiss?).to be_falsy
      end
    end

    context 'when user has no person' do
      before do
        allow(user).to receive(:person).and_return(nil)
      end

      it 'denies access' do
        expect(subject.dismiss?).to be_falsy
      end
    end
  end

  describe 'private methods' do
    describe '#hbx_staff?' do
      context 'when user has hbx_staff_role' do
        before do
          FactoryBot.create(:hbx_staff_role, person: person)
        end

        it 'returns true' do
          expect(subject.send(:hbx_staff?)).to be_truthy
        end
      end

      context 'when user does not have hbx_staff_role' do
        it 'returns false' do
          expect(subject.send(:hbx_staff?)).to be_falsy
        end
      end

      context 'when user has no person' do
        before do
          allow(user).to receive(:person).and_return(nil)
        end

        it 'returns false' do
          expect(subject.send(:hbx_staff?)).to be_falsy
        end
      end
    end

    describe '#modify_admin_tabs?' do
      context 'when user has hbx_staff_role with modify_admin_tabs permission' do
        let(:permission) { FactoryBot.create(:permission, modify_admin_tabs: true) }
        let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person) }

        before do
          allow(hbx_staff_role).to receive(:permission).and_return(permission)
        end

        it 'returns true' do
          expect(subject.send(:modify_admin_tabs?)).to be_truthy
        end
      end

      context 'when user has hbx_staff_role without modify_admin_tabs permission' do
        let(:permission) { FactoryBot.create(:permission, modify_admin_tabs: false) }
        let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person) }

        before do
          allow(hbx_staff_role).to receive(:permission).and_return(permission)
        end

        it 'returns false' do
          expect(subject.send(:modify_admin_tabs?)).to be_falsy
        end
      end

      context 'when user has hbx_staff_role without permission object' do
        let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person) }

        before do
          allow(hbx_staff_role).to receive(:permission).and_return(nil)
        end

        it 'returns false' do
          expect(subject.send(:modify_admin_tabs?)).to be_falsy
        end
      end

      context 'when user does not have hbx_staff_role' do
        it 'returns false' do
          expect(subject.send(:modify_admin_tabs?)).to be_falsy
        end
      end
    end
  end
end
