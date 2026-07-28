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

    context "and new date the same as the current date_of_record" do
      it "should leave the date unchanged" do
        TimeKeeper.set_date_of_record_unprotected!(base_date)
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
      before :each do
        allow(TimeKeeper.instance).to receive(:push_date_of_record)
        allow(TimeKeeper.instance).to receive(:push_date_change_event)
        TimeKeeper.set_date_of_record_unprotected!(base_date)
      end

      it "should send the new date_of_record to registered models for each day" do
        expect(TimeKeeper.instance).to receive(:push_date_of_record).exactly(3).times
        TimeKeeper.set_date_of_record(base_date + 3.days)
      end

      # The catch-up loop is driven by the recorded advance, not by re-reading
      # the date cache on each pass. A cache the loop does not control must not
      # be able to change where the sequence starts or how far it gets.
      it "advances one day at a time starting from the last recorded advance" do
        advanced_dates = []
        allow(TimeKeeper.instance).to receive(:advance_date_of_record) { |date| advanced_dates << date }

        TimeKeeper.set_date_of_record(base_date + 3.days)

        expect(advanced_dates).to eq([base_date + 1.day, base_date + 2.days, base_date + 3.days])
      end

      it "should persist in the local data storage the new date_of_record for each successful advance"
      it "should send a syslog info message to the enterprise logger for each successful advance"
    end

    context "and no advance has been recorded (CCAOM-349)" do
      before :each do
        allow(TimeKeeper.instance).to receive(:push_date_of_record)
        allow(TimeKeeper.instance).to receive(:push_date_change_event)
        Rails.cache.delete(TimeKeeper::CACHE_KEY)
        Rails.cache.delete(TimeKeeper::ADVANCE_KEY)
      end

      it "runs the day's events instead of silently skipping" do
        expect(TimeKeeper.instance).to receive(:push_date_of_record).once
        TimeKeeper.set_date_of_record(base_date)
      end

      it "seeds the date cache with the new date" do
        TimeKeeper.set_date_of_record(base_date)
        expect(Rails.cache.read(TimeKeeper::CACHE_KEY)).to eq base_date.strftime("%Y-%m-%d")
      end

      it "records the advance so the day is not run twice" do
        TimeKeeper.set_date_of_record(base_date)
        expect(Rails.cache.read(TimeKeeper::ADVANCE_KEY)).to eq base_date.strftime("%Y-%m-%d")
      end

      it "is a no-op on a duplicate trigger after recovery" do
        TimeKeeper.set_date_of_record(base_date)
        expect(TimeKeeper.instance).not_to receive(:push_date_of_record)
        TimeKeeper.set_date_of_record(base_date)
      end

      context "and a reader has already repopulated the date cache" do
        before :each do
          # A web request or background job reads the date after the cache was
          # flushed. That read writes a fabricated date back to CACHE_KEY. A
          # populated date cache is therefore not evidence that the day's
          # advance events have run, and must not suppress them.
          TimeKeeper.date_of_record
        end

        it "still runs the day's events" do
          expect(TimeKeeper.instance).to receive(:push_date_of_record).once
          TimeKeeper.set_date_of_record(base_date)
        end
      end

      context "logging" do
        let(:notification_stub) { TkNotifyWrapper::SimpleWrapper.new(ActiveSupport::Notifications) }

        before :each do
          stub_const("ActiveSupport::Notifications", notification_stub)
        end

        it "should send a syslog critical error to the enterprise logger" do
          notification_stub.expect_event("acapi.critical.application.enroll.logging", {:body => "date_of_record advance ledger missing - running events for #{base_date}"})
          expect { TimeKeeper.set_date_of_record(base_date) }.to raise_error(TkNotifyWrapper::ExpectedLogCallInvoked)
        end
      end
    end
  end

  context "datetime_of_record", dbclean: :after_each do
    # The Rails process runs in UTC (config.time_zone is unset), so the
    # time-of-day component is the UTC wall clock. 02:30:45 UTC on 2024-01-15
    # is 21:30:45 ET on 2024-01-14, which makes the sourcing zone unambiguous
    # in the assertion below.
    let(:utc_instant) { Time.utc(2024, 1, 15, 2, 30, 45) }

    before :each do
      TimeKeeper.set_date_of_record_unprotected!(Date.new(2024, 1, 14))
      allow(Time).to receive(:current).and_return(utc_instant)
    end

    it "combines date_of_record with the UTC time-of-day" do
      result = TimeKeeper.datetime_of_record

      expect(result.to_date).to eq(Date.new(2024, 1, 14))
      expect([result.hour, result.min, result.sec]).to eq([2, 30, 45])
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
