# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "clone_consumer_role")

if ExchangeTestingConfigurationHelper.individual_market_is_enabled?
  describe CloneConsumerRole do
    let(:given_task_name) { "clone_consumer_role" }
    subject { CloneConsumerRole.new(given_task_name, double(:current_scope => nil)) }

    describe "given a task name" do
      it "has the given task name" do
        expect(subject.name).to eql given_task_name
      end
    end

    describe "move the user from person1 to person2 ", dbclean: :after_each do
      let!(:person1) { FactoryBot.create(:person, :with_consumer_role) }
      let!(:person2) { FactoryBot.create(:person) }

      it "should clone consumer role from person1 to person2" do
        ClimateControl.modify :old_hbx_id => person1.hbx_id, :new_hbx_id => person2.hbx_id do
          expect(person1.consumer_role).not_to eq nil
          expect(person2.consumer_role).to eq nil
          subject.migrate
          person1.reload
          person2.reload
          expect(person1.consumer_role).not_to eq nil
          expect(person2.consumer_role).not_to eq nil
        end
      end
    end

    describe "not move the consumer role if person1 has no consumer role " do
      let(:person1) { FactoryBot.create(:person) }
      let(:person2){ FactoryBot.create(:person) }

      it "should not move user from person1 to person2" do
        ClimateControl.modify :old_hbx_id => person1.hbx_id, :new_hbx_id => person2.hbx_id do
          subject.migrate
          expect(person2.consumer_role).to eq nil
        end
      end
    end
  end
end
