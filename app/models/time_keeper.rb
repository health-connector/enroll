class TimeKeeper
  include Config::AcaModelConcern
  include Mongoid::Document
  include Singleton
  include Acapi::Notifiers
  extend Acapi::Notifiers

  CACHE_KEY = "timekeeper/date_of_record"

  # time zone management

  def initialize
  end

  def self.local_time(a_time)
    a_time.in_time_zone("Eastern Time (US & Canada)")
  end

  def self.format_date(a_time)
    local_time(a_time).strftime('%m/%d/%Y')
  end

  def self.format_date_time(a_time)
    local_time(a_time).strftime('%m/%d/%Y %I:%M%p')
  end

  def self.exchange_zone
    "Eastern Time (US & Canada)"
  end

  def self.start_of_exchange_day_from_utc(date)
    start_of_day = date.beginning_of_day
    Time.use_zone(exchange_zone) do
      Time.zone.local(start_of_day.year, start_of_day.month, start_of_day.day, 0,0,0)
    end.utc
  end

  def self.end_of_exchange_day_from_utc(date)
    start_of_next_day = (date + 1.day).beginning_of_day
    Time.use_zone(exchange_zone) do
      Time.zone.local(start_of_next_day.year, start_of_next_day.month, start_of_next_day.day, 0,0,0)
    end.utc
  end

  def self.date_according_to_exchange_at(a_time)
    a_time.in_time_zone(exchange_zone).to_date
  end

  def self.set_date_of_record(new_date)
    Rails.logger.info("[TimeKeeper] STEP 1: set_date_of_record called with new_date=#{new_date.inspect}")
    new_date = new_date.to_date

    Rails.cache.delete(CACHE_KEY) # TEMP: force cache-miss path for testing - DO NOT COMMIT
    Rails.logger.info("[TimeKeeper] STEP 2: cache deleted for #{CACHE_KEY} (TEMP test-only)")

    last_recorded_date = instance.cached_date_of_record
    Rails.logger.info("[TimeKeeper] STEP 3: read cached_date_of_record => #{last_recorded_date.inspect} (new_date=#{new_date})")

    if last_recorded_date.blank?
      # Cache state was lost or is unreachable. A missing value must never be
      # treated as "day already processed" - run the day's events (CCAOM-349).
      Rails.logger.info("[TimeKeeper] STEP 4: cache miss branch - last_recorded_date is blank, running events for #{new_date}")
      log("date_of_record missing at advance - running events for #{new_date}", {:severity => :critical})
      instance.set_date_of_record(new_date)
      Rails.logger.info("[TimeKeeper] STEP 5: cache seeded with #{new_date}, calling push_date_of_record")
      instance.push_date_of_record
      Rails.logger.info("[TimeKeeper] STEP 6: push_date_of_record done, calling push_date_change_event")
      instance.push_date_change_event
      Rails.logger.info("[TimeKeeper] STEP 7: cache-miss branch complete")
    elsif last_recorded_date != new_date
      Rails.logger.info("[TimeKeeper] STEP 4: cache present and differs - last_recorded_date=#{last_recorded_date}, new_date=#{new_date}")
      if last_recorded_date > new_date
        Rails.logger.info("[TimeKeeper] STEP 5: rejecting backward time travel (#{last_recorded_date} > #{new_date})")
        log("Attempt made to set date to past: #{new_date}", {:severity => :error})
        raise StandardError, "system may not go backward in time"
      else
        number_of_days = (new_date - instance.date_of_record).to_i
        Rails.logger.info("[TimeKeeper] STEP 5: advancing forward #{number_of_days} day(s), one day at a time")
        number_of_days.times do |i|
          next_date = instance.date_of_record + 1.day
          Rails.logger.info("[TimeKeeper] STEP 6.#{i + 1}: advancing to #{next_date}")
          instance.set_date_of_record(next_date)
          instance.push_date_of_record
          instance.push_date_change_event
        end
        Rails.logger.info("[TimeKeeper] STEP 7: forward advance complete, now at #{instance.date_of_record}")
      end
    else
      Rails.logger.info("[TimeKeeper] STEP 4: cache already equals new_date=#{new_date} - no-op")
    end

    Rails.logger.info("[TimeKeeper] STEP 8: set_date_of_record returning #{instance.date_of_record}")
    instance.date_of_record
  end

  # DO NOT EVER USE OUTSIDE OF TESTS
  def self.set_date_of_record_unprotected!(new_date)
    new_date = new_date.to_date
    instance.set_date_of_record(new_date) if instance.cached_date_of_record != new_date
    instance.date_of_record
  end

  def self.date_of_record
    instance.date_of_record
  end

  def self.datetime_of_record
    instant = Time.current
    instance.date_of_record.to_datetime + instant.hour.hours + instant.min.minutes + instant.sec.seconds
  end

  def set_date_of_record(new_date)
    Rails.logger.info("[TimeKeeper] STEP: writing cache #{CACHE_KEY} = #{new_date.strftime('%Y-%m-%d')}")
    Rails.cache.write(CACHE_KEY, new_date.strftime("%Y-%m-%d"))
  end

  # Raw cache read: returns nil on a miss instead of fabricating a value.
  # Only set_date_of_record decides what a miss means; readers fall back below.
  def cached_date_of_record
    found_value = Rails.cache.read(CACHE_KEY)
    Rails.logger.info("[TimeKeeper] STEP: cache read #{CACHE_KEY} => #{found_value.inspect}")
    return nil if found_value.blank?

    Date.strptime(found_value, "%Y-%m-%d")
  end

  def date_of_record
    tl_value = thread_local_date_of_record
    return tl_value unless tl_value.blank?

    cached = cached_date_of_record
    return cached if cached.present?

    Rails.logger.info("[TimeKeeper] STEP: date_of_record cache miss on read - falling back to self.class.date_according_to_exchange_at(DateTime.current)")
    log("date_of_record not available for TimeKeeper - using self.class.date_according_to_exchange_at(DateTime.current)")
    self.class.date_according_to_exchange_at(DateTime.current)
  end

  def push_date_of_record
    notify_logger("TimeKeeper advance day started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
    BenefitSponsors::ScheduledEvents::AcaShopScheduledEvents.advance_day(self.date_of_record)
    BenefitSponsorship.advance_day(self.date_of_record)
    # EmployerProfile.advance_day(self.date_of_record)
    Family.advance_day(self.date_of_record) if individual_market_is_enabled?
    HbxEnrollment.advance_day(self.date_of_record)
    CensusEmployee.advance_day(self.date_of_record)
    ConsumerRole.advance_day(self.date_of_record)
    notify_logger("TimeKeeper advance day ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
  end

  def push_date_change_event
    begin
      BenefitSponsors::BenefitApplications::BenefitApplication.date_change_event(self.date_of_record)
    rescue Exception => e
      Rails.logger.error { "Couldn't trigger benefit application date change events due to #{e.inspect}" }
    end
  end

  def notify_logger(message)
    Rails.logger.info(message)
    log(message)
  end

  def self.with_cache
    Thread.current[:time_keeper_local_cached_date] = date_of_record
    yield
    Thread.current[:time_keeper_local_cached_date] = nil
  end

  def thread_local_date_of_record
    Thread.current[:time_keeper_local_cached_date]
  end
end
