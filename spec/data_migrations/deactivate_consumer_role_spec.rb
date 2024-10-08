# frozen_string_literal: true

require "rails_helper"
if ExchangeTestingConfigurationHelper.individual_market_is_enabled?
  require File.join(Rails.root, "app", "data_migrations", "deactivate_consumer_role")
  describe DeactivateConsumerRole, dbclean: :after_each do

    let(:given_task_name) { "deactivate_consumer_role" }
    subject { DeactivateConsumerRole.new(given_task_name, double(:current_scope => nil)) }

    describe "given a task name" do

      it "has the given task name" do
        expect(subject.name).to eql given_task_name
      end
    end

    describe "deactivate consumer role" do
      let(:person) { FactoryBot.create(:person, :with_consumer_role, hbx_id: "12345678")}

      it "should change is_active field" do
        ClimateControl.modify :hbx_id => "12345678" do
          role_status = person.consumer_role
          role_status.is_active = true
          role_status.save
          subject.migrate
          person.reload
          expect(person.consumer_role.is_active).to eq false
        end
      end
    end
  end
end
