# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "remove_consumer_role")

if ExchangeTestingConfigurationHelper.individual_market_is_enabled?
  describe RemoveConsumerRole do

    let(:given_task_name) { "remove_consumer_role" }
    subject { RemoveConsumerRole.new(given_task_name, double(:current_scope => nil)) }

    describe "given a task name" do
      it "has the given task name" do
        expect(subject.name).to eql given_task_name
      end
    end

    describe "remove consumer role for person with consumer and resident roles", dbclean: :after_each do
      let!(:person1) { FactoryBot.create(:person, :with_resident_role, :with_consumer_role, hbx_id: '58e3dc7dqwewqewqe') }
      let!(:primary_family) { FactoryBot.create(:family, :with_primary_family_member, person: person1) }
      let!(:ivl_enrollment) do
        FactoryBot.create(:hbx_enrollment, :individual_unassisted, family: person1.primary_family, household: primary_family.active_household,
                                                                   kind: 'individual', consumer_role_id: person1.consumer_role.id, resident_role_id: person1.resident_role.id)
      end

      it "deletes the consumer role for person1" do
        ClimateControl.modify :p_to_fix_id => '58e3dc7dqwewqewqe' do
          subject.migrate
          person1.reload
          expect(person1.consumer_role).to be_nil
        end
      end

      it "does not delete the resident role for person1" do
        ClimateControl.modify :p_to_fix_id => '58e3dc7dqwewqewqe' do
          subject.migrate
          person1.reload
          expect(person1.resident_role).not_to be_nil
        end
      end

      it "sets the kind attribute on person1's enrollment to coverall" do
        ClimateControl.modify :p_to_fix_id => '58e3dc7dqwewqewqe' do
          subject.migrate
          person1.reload
          expect(person1.primary_family.active_household.hbx_enrollments.first.kind).to eq("coverall")
        end
      end

      it "sets the consumer_role_id on person1's enrollment to nil" do
        ClimateControl.modify :p_to_fix_id => '58e3dc7dqwewqewqe' do
          subject.migrate
          person1.reload
          expect(person1.primary_family.active_household.hbx_enrollments.first.consumer_role_id).to be(nil)
        end
      end

      it "leaves the resident_role_id on person1's enrollment to be the resident role of person1" do
        ClimateControl.modify :p_to_fix_id => '58e3dc7dqwewqewqe' do
          subject.migrate
          person1.reload
          expect(person1.primary_family.active_household.hbx_enrollments.first.resident_role_id).to eq(person1.resident_role.id)
        end
      end
    end
  end
end
