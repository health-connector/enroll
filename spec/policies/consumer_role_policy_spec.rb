# frozen_string_literal: true

require "rails_helper"

if ExchangeTestingConfigurationHelper.individual_market_is_enabled?
  describe ConsumerRolePolicy do
    subject { described_class }
    let(:consumer_role) { FactoryBot.create(:consumer_role) }
    let(:consumer_person) { FactoryBot.create(:person, :with_consumer_role) }
    let(:broker_person) { FactoryBot.create(:person, :with_broker_role) }
    let(:assister_person) { FactoryBot.create(:person, :with_assister_role) }
    let(:csr_person) { FactoryBot.create(:person, :with_csr_role) }
    let(:employee_person) { FactoryBot.create(:person, :with_employee_role) }

    permissions :privacy? do
      it "grants access when consumer" do
        expect(subject).to permit(FactoryBot.build(:user, :consumer, person: consumer_person), ConsumerRole)
      end

      it "grants access when broker" do
        expect(subject).to permit(FactoryBot.build(:user, :broker, person: broker_person), ConsumerRole)
      end

      it "grants access when assister" do
        expect(subject).to permit(FactoryBot.build(:user, :assister, person: assister_person), ConsumerRole)
      end

      it "grants access when csr" do
        expect(subject).to permit(FactoryBot.build(:user, :csr, person: csr_person), ConsumerRole)
      end

      it "grants access when user without roles" do
        expect(subject).to permit(User.new, ConsumerRole)
      end

      it "denies access when employee" do
        expect(subject).not_to permit(FactoryBot.build(:user, :employee, person: employee_person), ConsumerRole)
      end

      it "denies access when employer_staff" do
        expect(subject).not_to permit(FactoryBot.build(:user, :employer_staff), ConsumerRole)
      end
    end

    permissions :edit? do
      let(:hbx_staff_user) {FactoryBot.create(:user, person: person)}
      let(:person) { FactoryBot.create(:person, :with_hbx_staff_role) }
      let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person)}
      let(:permission) { FactoryBot.create(:permission)}

      it "grants access when hbx_staff" do
        allow(hbx_staff_role).to receive(:permission).and_return permission
        allow(person).to receive(:hbx_staff_role).and_return hbx_staff_role
        allow(hbx_staff_user).to receive(:person).and_return person
        allow(permission).to receive(:can_update_ssn).and_return true
        expect(subject).to permit(hbx_staff_user, consumer_role)
      end

      it "denies access when normal user" do
        expect(subject).not_to permit(User.new, consumer_role)
      end

      context "consumer" do
        let(:user) {FactoryBot.create(:user, :consumer)}
        let(:person) { FactoryBot.build(:person) }

        before :each do
          allow(user).to receive(:person).and_return person
        end

        it "grants access" do
          allow(person).to receive(:consumer_role).and_return consumer_role
          expect(subject).to permit(user, consumer_role)
        end

        it "denies access" do
          allow(person).to receive(:consumer_role).and_return ConsumerRole.new
          expect(subject).not_to permit(user, consumer_role)
        end
      end
    end
  end
end
