# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "trigger_shop_notices")

describe TriggerShopNotices, dbclean: :after_each do

  let(:given_task_name) { "trigger_shop_notices" }
  subject { TriggerShopNotices.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe '#trigger_employer_notice' do
    let(:employer_profile1){ FactoryBot.create(:employer_profile) }
    let(:employer_profile2){ FactoryBot.create(:employer_profile) }

    it "should trigger employer_notice job in queue" do
      ClimateControl.modify recipient_ids: "#{employer_profile1.fein}, #{employer_profile2.fein}",event: 'initial_employer_ineligibility_notice', action: 'employer_notice' do

        ActiveJob::Base.queue_adapter = :test
        ActiveJob::Base.queue_adapter.enqueued_jobs = []
        subject.migrate
        queued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.find do |job_info|
          job_info[:job] == ShopNoticesNotifierJob
        end
        expect(queued_job[:args]).not_to be_empty
        expect(queued_job[:args].include?(employer_profile1.id.to_s)).to be_truthy
        expect(queued_job[:args].include?("initial_employer_ineligibility_notice")).to be_truthy
      end
    end
  end
end
