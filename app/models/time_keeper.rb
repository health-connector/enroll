class TimeKeeper
  include Config::AcaModelConcern
  include Mongoid::Document
  include Singleton
  include Acapi::Notifiers
  extend Acapi::Notifiers

  CACHE_KEY = "timekeeper/date_of_record"
  ADVANCE_KEY = "timekeeper/last_advanced_on".freeze

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
    new_date = new_date.to_date
    last_advanced = instance.last_advanced_on

    if last_advanced.blank?
      log("date_of_record advance ledger missing - running events for #{new_date}", {:severity => :critical})
      instance.advance_date_of_record(new_date)
    elsif last_advanced != new_date
      if last_advanced > new_date
        log("Attempt made to set date to past: #{new_date}", {:severity => :error})
        raise StandardError, "system may not go backward in time"
      else
        ((last_advanced + 1.day)..new_date).each do |day|
          instance.advance_date_of_record(day)
        end
      end
    end
    instance.date_of_record
  end

  # DO NOT EVER USE OUTSIDE OF TESTS
  def self.set_date_of_record_unprotected!(new_date)
    new_date = new_date.to_date
    instance.set_date_of_record(new_date) if instance.date_of_record != new_date
    instance.mark_advanced(new_date)
    instance.date_of_record
  end

  def self.date_of_record
    instance.date_of_record
  end

  def self.datetime_of_record
    instant = Time.current
    instance.date_of_record.to_datetime + instant.hour.hours + instant.min.minutes + instant.sec.seconds
  end

  def advance_date_of_record(new_date)
    set_date_of_record(new_date)
    push_date_of_record
    push_date_change_event
    mark_advanced(new_date)
  end

  # Records which day the advance events last ran for. CACHE_KEY can't answer
  # that - a reader that misses repopulates it with a dynamic fallback date.
  # Written after the events so a partial advance is retried, not marked done.
  def mark_advanced(new_date)
    Rails.cache.write(ADVANCE_KEY, new_date.strftime("%Y-%m-%d"))
  end

  def last_advanced_on
    found_value = Rails.cache.read(ADVANCE_KEY)
    return nil if found_value.blank?

    Date.strptime(found_value, "%Y-%m-%d")
  end

  # Bypassing rubocop here to avoid the unnecessary risk of a name change to a load-bearing legacy method.
  # rubocop:disable  Naming/AccessorMethodName
  def set_date_of_record(new_date)
    Rails.cache.write(CACHE_KEY, new_date.strftime("%Y-%m-%d"))
  end
  # rubocop:enable  Naming/AccessorMethodName

  def date_of_record
    tl_value = thread_local_date_of_record
    return tl_value unless tl_value.blank?
    found_value = Rails.cache.fetch(CACHE_KEY) do
      # The exchange business day is Eastern. This process runs in UTC, so
      # Date.current is a day ahead between UTC midnight and the start of the
      # Eastern day, which would hand the app tomorrow's date on a cache miss.
      log("date_of_record not available for TimeKeeper - using exchange time zone")
      self.class.date_according_to_exchange_at(Time.current).strftime("%Y-%m-%d")
    end
    Date.strptime(found_value, "%Y-%m-%d")
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
