class TimeKeeper
  include Config::AcaModelConcern
  include Mongoid::Document
  include Singleton
  include Acapi::Notifiers
  extend Acapi::Notifiers

  CACHE_KEY = "timekeeper/date_of_record"
  ADVANCE_KEY = "timekeeper/last_advanced_on".freeze
  ADVANCE_CLAIM_PREFIX = "timekeeper/advancing/".freeze
  ADVANCE_CLAIM_TTL = 6.hours

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
      instance.notify_logger("date_of_record advance ledger missing - running events for #{new_date} on #{Socket.gethostname}", :warn)
      instance.advance_date_of_record(new_date)
    elsif last_advanced != new_date
      if last_advanced > new_date
        instance.notify_logger("Attempt made to set date to past: #{new_date} on #{Socket.gethostname}", :error)
        raise StandardError, "system may not go backward in time"
      else
        instance.notify_logger("TimeKeeper advancing from #{last_advanced} to #{new_date} on #{Socket.gethostname}")
        # A process that loses the claim for a day stops here rather than moving
        # on to later days, where it would otherwise race the claim holder again.
        ((last_advanced + 1.day)..new_date).each do |day|
          break unless instance.advance_date_of_record(day)
        end
      end
    else
      instance.notify_logger("TimeKeeper advance for #{new_date} skipped on #{Socket.gethostname} - already advanced")
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

  # Built through Time.zone.local, not date.to_datetime, so the time of day comes
  # from the exchange zone instead of being mislabeled UTC. Returned as a DateTime
  # rather than a TimeWithZone, since is_a?(::Date) checks elsewhere depend on that type.
  def self.datetime_of_record
    date = instance.date_of_record
    instant = Time.current.in_time_zone(exchange_zone)
    Time.use_zone(exchange_zone) do
      Time.zone.local(date.year, date.month, date.day, instant.hour, instant.min, instant.sec)
    end.to_datetime
  end

  # Runs the day's events at most once across processes. Returns false when
  # another process holds the claim for the day, true otherwise.
  #
  # A claim held by a process that crashed is not reclaimed. It stays until
  # ADVANCE_CLAIM_TTL expires, and the skip log names the holder.
  def advance_date_of_record(new_date)
    owner = claim_advance(new_date)
    unless owner
      notify_logger("TimeKeeper advance for #{new_date} skipped on #{Socket.gethostname} - " \
                    "claimed by #{Rails.cache.read(advance_claim_key(new_date)) || 'unknown'}", :warn)
      return false
    end

    begin
      # The marker is read again after claiming because another process may
      # have finished this day between the caller's read and this claim.
      done = last_advanced_on
      if done.present? && done >= new_date
        notify_logger("TimeKeeper advance for #{new_date} skipped on #{Socket.gethostname} - already advanced")
        return true
      end

      set_date_of_record(new_date)
      push_date_of_record
      push_date_change_event
      mark_advanced(new_date)
      notify_logger("TimeKeeper marked #{new_date} advanced on #{Socket.gethostname}")
      true
    ensure
      release_advance_claim(new_date, owner)
    end
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
      log("date_of_record cache miss - returning and restoring the exchange date via date_according_to_exchange_at")
      self.class.date_according_to_exchange_at(Time.current).strftime("%Y-%m-%d")
    end
    Date.strptime(found_value, "%Y-%m-%d")
  end

  def push_date_of_record
    started_at = Time.now
    notify_logger("TimeKeeper advance day started at #{started_at.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')} for #{date_of_record} on #{Socket.gethostname}")
    BenefitSponsors::ScheduledEvents::AcaShopScheduledEvents.advance_day(self.date_of_record)
    BenefitSponsorship.advance_day(self.date_of_record)
    # EmployerProfile.advance_day(self.date_of_record)
    Family.advance_day(self.date_of_record) if individual_market_is_enabled?
    HbxEnrollment.advance_day(self.date_of_record)
    CensusEmployee.advance_day(self.date_of_record)
    ConsumerRole.advance_day(self.date_of_record)
    notify_logger("TimeKeeper advance day ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')} for #{date_of_record} on #{Socket.gethostname} - took #{(Time.now - started_at).round} seconds")
  end

  def push_date_change_event
    begin
      BenefitSponsors::BenefitApplications::BenefitApplication.date_change_event(self.date_of_record)
    rescue Exception => e
      Rails.logger.tagged(self.class.name) { Rails.logger.error("Couldn't trigger benefit application date change events due to #{e.inspect}") }
    end
  end

  def notify_logger(message, severity = :info)
    Rails.logger.tagged(self.class.name) { Rails.logger.public_send(severity, message) }
    log(message, {:severity => severity})
  end

  def self.with_cache
    Thread.current[:time_keeper_local_cached_date] = date_of_record
    yield
    Thread.current[:time_keeper_local_cached_date] = nil
  end

  def thread_local_date_of_record
    Thread.current[:time_keeper_local_cached_date]
  end

  private

  def advance_claim_key(day)
    "#{ADVANCE_CLAIM_PREFIX}#{day.strftime('%Y-%m-%d')}"
  end

  # Returns the owner string when the claim is taken, nil when another process
  # holds it, and :unclaimed when the cache store cannot be reached.
  #
  # A failed write means either the key exists or the store errored. Reading
  # the key tells them apart. When the store is unavailable the day proceeds
  # without a claim: skipping would leave the date un-advanced for every
  # process, which is worse than the race the claim guards against.
  def claim_advance(day)
    key = advance_claim_key(day)
    owner = "#{Socket.gethostname} pid=#{Process.pid} since #{Time.now.utc.iso8601}"
    return owner if Rails.cache.write(key, owner, unless_exist: true, expires_in: ADVANCE_CLAIM_TTL)
    return nil if Rails.cache.read(key).present?

    notify_logger("TimeKeeper claim store unavailable for #{day} on #{Socket.gethostname} - advancing without a claim", :warn)
    :unclaimed
  end

  # Deletes the claim only when it still holds our owner string, so a claim
  # taken by another process after ours expired is left alone. The read and the
  # delete are separate calls and not atomic, but ADVANCE_CLAIM_TTL is far longer
  # than an advance takes, so the claim cannot expire and change hands between them.
  # A stored value never equals :unclaimed, so an unclaimed run deletes nothing.
  def release_advance_claim(day, owner)
    key = advance_claim_key(day)
    Rails.cache.delete(key) if Rails.cache.read(key) == owner
  end
end
