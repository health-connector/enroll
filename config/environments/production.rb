# frozen_string_literal: true

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true
  # config.cache_store = :memory_store

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = ENV.fetch('ENROLL_REVIEW_ENVIRONMENT', nil) == 'true'
  config.action_controller.perform_caching = true

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like
  # NGINX, varnish or squid.
  # config.action_dispatch.rack_cache = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.serve_static_files = false

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = Uglifier.new(harmony: true)
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = ENV.fetch('ENABLE_FORCE_SSL', nil) == 'true'

  # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  config.log_level = :debug

  # Prepend all log lines with the following tags.
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups.
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store
  # config.cache_store = :redis_store, { :host => "localhost",
  #:port => 6379,
  #:db => 0,
  #:password => "mysecret",
  #:namespace => "cache",
  #:expires_in => 90.minutes }

  config.cache_store = :redis_store, "redis://#{ENV.fetch('REDIS_HOST_ENROLL', nil)}:6379", {  }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = Logger::SimpleJsonFormatter.new

  # Do not dump schema after migrations.
  #  config.active_record.dump_schema_after_migration = false
  #  config.acapi.add_async_subscription(Subscribers::DateChange)
  config.acapi.publish_amqp_events = true
  config.acapi.app_id = "enroll"
  config.acapi.remote_broker_uri = ENV.fetch('RABBITMQ_URL', nil)
  config.acapi.remote_request_exchange = "#{ENV.fetch('HBX_ID', nil)}.#{ENV.fetch('ENV_NAME', nil)}.e.fanout.requests"
  config.acapi.remote_event_queue = "#{ENV.fetch('HBX_ID', nil)}.#{ENV.fetch('ENV_NAME', nil)}.q.application.enroll.inbound_events"
  config.action_mailer.default_url_options = { :host => ENV.fetch('ENROLL_FQDN', nil).to_s }
  config.acapi.hbx_id = ENV.fetch('HBX_ID', nil).to_s
  config.acapi.environment_name = ENV.fetch('ENV_NAME', nil).to_s

  # Add Google Analytics tracking ID
  config.ga_tracking_id = ENV.fetch('GA_TRACKING_ID', 'dummy')
  config.ga_tagmanager_id = ENV.fetch('GA_TAGMANAGER_ID', 'dummy')

  # Add consumer checkbook config values - unused in MA, but requires vals for startup
  config.checkbook_services_remote_access_key = "dummy"
  config.checkbook_services_base_url = "https://dummy.org"

  # for Employer Auto Pay
  config.wells_fargo_api_url = ENV.fetch('WF_API_URL', 'dummy')
  config.wells_fargo_api_key = ENV.fetch('WF_API_KEY', 'dummy')

  config.wells_fargo_biller_key = ENV.fetch('WF_BILLER_KEY', 'dummy')
  config.wells_fargo_api_secret = ENV.fetch('WF_API_SECRET', 'dummy')
  config.wells_fargo_api_version = ENV.fetch('WF_API_VERSION', 'dummy')
  config.wells_fargo_private_key_location = '/wfpk.pem'
  config.wells_fargo_api_date_format = '%Y-%m-%dT%H:%M:%S.0000000%z'

  # Mongoid logger levels
  Mongoid.logger.level = Logger::ERROR
  Mongo::Logger.logger.level = Logger::ERROR

  IdentityVerification::InteractiveVerificationService.slug!

  unless ENV.fetch("CLOUDFLARE_PROXY_IPS", nil).blank?
    proxy_ip_env = ENV.fetch("CLOUDFLARE_PROXY_IPS", nil)
    proxy_ips = proxy_ip_env.split(",").map(&:strip).map { |proxy| IPAddr.new(proxy) }
    all_proxies = proxy_ips + ActionDispatch::RemoteIp::TRUSTED_PROXIES
    config.middleware.swap ActionDispatch::RemoteIp, ActionDispatch::RemoteIp, false, all_proxies
  end
end