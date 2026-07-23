# frozen_string_literal: true

require 'rails_helper'

module TkNotifyWrapper
  class ExpectedLogCallInvoked < StandardError; end

  class SimpleWrapper < SimpleDelegator


    def expect_event(event, pay)
      @event = event
      @payload = pay
    end

    def instrument(event, payload)
      raise ExpectedLogCallInvoked if event == @event && payload == @payload

      super(event,payload)
    end
  end
end

RSpec.describe TimeKeeper, type: :model do

  context "the system initializes" do
    context "and a date_of_record value isn't available in the locally-persisted store" do
      let(:notification_stub) { TkNotifyWrapper::SimpleWrapper.new(ActiveSupport::Notifications) }
      before :each do
        Rails.cache.delete(TimeKeeper::CACHE_KEY)
        stub_const("ActiveSupport::Notifications", notification_stub)
      end

      it "should send a syslog info message to the enterprise logger" do
        notification_stub.expect_event("acapi.info.application.enroll.logging", {:body => "date_of_record not available for TimeKeeper - using Date.current"})
        expect { TimeKeeper.date_of_record }.to raise_error(TkNotifyWrapper::ExpectedLogCallInvoked)
      end

      it "should return Date.current without writing it back to the cache" do
        expect(TimeKeeper.date_of_record).to eq Date.current
        expect(Rails.cache.read(TimeKeeper::CACHE_KEY)).to be_nil
      end

      context "and the date_of_record isn't available from enterprise service" do
        it "should send a syslog critical error to the enterprise logger"
        it "should halt the system initialization process to avoid corrupting records"
      end
    end
  end

  context "a message is received with a new date_of_record", dbclean: :after_each do
    let(:base_date)   { Date.current }
    let(:past_date)   { Date.current - 5.days }
    let(:next_day)    { Date.current + 1.day  }
    let(:future_date) { Date.current + 5.days }

    let(:date_of_record) { TimeKeeper.set_date_of_record(base_date) }

    context "and the cache value is missing at the advance (CCAOM-349)" do
      before :each do
        allow(TimeKeeper.instance).to receive(:push_date_of_record)
        allow(TimeKeeper.instance).to receive(:push_date_change_event)
        Rails.cache.delete(TimeKeeper::CACHE_KEY)
      end

      it "runs the day's events instead of silently skipping" do
        expect(TimeKeeper.instance).to receive(:push_date_of_record).once
        TimeKeeper.set_date_of_record(base_date)
      end

      it "seeds the cache with the new date" do
        TimeKeeper.set_date_of_record(base_date)
        expect(Rails.cache.read(TimeKeeper::CACHE_KEY)).to eq base_date.strftime("%Y-%m-%d")
      end

      it "is a no-op on a duplicate trigger after recovery" do
        TimeKeeper.set_date_of_record(base_date)
        expect(TimeKeeper.instance).not_to receive(:push_date_of_record)
        TimeKeeper.set_date_of_record(base_date)
      end
    end

    context "and new date the same as the current date_of_record" do
      before :each do
        TimeKeeper.set_date_of_record_unprotected!(base_date)
      end

      it "should leave the date unchanged" do
        expect(TimeKeeper.set_date_of_record(base_date)).to eq base_date
      end
    end

    context "and new date is prior to the current date_of_record" do
      # expect(TimeKeeper.set_date_of_record(past_date)).to raise_error(StandardError)

      let(:notification_stub) { TkNotifyWrapper::SimpleWrapper.new(ActiveSupport::Notifications) }
      before :each do
        TimeKeeper.set_date_of_record_unprotected!(base_date)
        stub_const("ActiveSupport::Notifications", notification_stub)
      end

      it "should send a syslog critical error to the enterprise logger" do
        notification_stub.expect_event("acapi.error.application.enroll.logging", {:body => "Attempt made to set date to past: #{past_date}"})
        expect { TimeKeeper.set_date_of_record(past_date) }.to raise_error(TkNotifyWrapper::ExpectedLogCallInvoked)
      end
    end

    context "and new date is one day later than current date_of_record" do
      let!(:hbx_profile) { FactoryBot.create(:hbx_profile) }
      before :each do
        TimeKeeper.set_date_of_record_unprotected!(base_date)
      end

      it "should advance the date" do
        expect(TimeKeeper.set_date_of_record(next_day)).to eq next_day
      end

      it "should send the new date_of_record to registered models"

      it "should persist the new date_of_record in the local data store"
      it "should send a syslog info message to the enterprise logger"
    end

    context "and new date is more than one day later than curent date_of_record" do
      it "should send the new date_of_record to registered models for each day"
      it "should persist in the local data storage the new date_of_record for each successful advance"
      it "should send a syslog info message to the enterprise logger for each successful advance"
    end
  end

  context "datetime_of_record time-of-day component", dbclean: :after_each do
    # 02:30:45 UTC on 2024-01-15 is 21:30:45 EST on 2024-01-14 - a near-UTC-
    # midnight instant where a UTC-sourced time-of-day is most visibly wrong:
    # the exchange day has already rolled back, but the raw UTC hour has not.
    let(:utc_instant) { Time.utc(2024, 1, 15, 2, 30, 45) }

    before :each do
      allow(Time).to receive(:now).and_return(utc_instant)
      TimeKeeper.set_date_of_record_unprotected!(Date.new(2024, 1, 14))
    end

    it "sources the time-of-day from the exchange (Eastern) zone, not UTC" do
      result = TimeKeeper.datetime_of_record

      expect(result.to_date).to eq(Date.new(2024, 1, 14))
      expect([result.hour, result.min, result.sec]).to eq([21, 30, 45])
    end
  end

  context "which can avoid local cache hits" do
    before :each do
      TimeKeeper.set_date_of_record_unprotected!(Date.today)
    end

    it "should return identical values for the life of the cache" do
      first_value = "first value"
      second_value = "second value"
      TimeKeeper.with_cache do
        first_value = TimeKeeper.date_of_record
        second_value = TimeKeeper.date_of_record
      end
      expect(first_value).to eq(second_value)
      expect(first_value).to equal(second_value)
    end
  end
end
