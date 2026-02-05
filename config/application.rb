# frozen_string_literal: true

require_relative 'boot'

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "rails/test_unit/railtie"
require "sprockets/railtie" # Uncomment this line for Rails 3.1+

# Configure fallbacks for mongoid errors:
require "i18n/backend/fallbacks"
require_relative '../app/models/hbx_id_generator'
require_relative '../app/models/identity_verification/interactive_verification_service'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require File.join(File.dirname(__FILE__), "json_log_format")

# Extends Psych (Ruby's YAML parser) to safely allow deserialization of specific application
# classes while maintaining protection against arbitrary code execution vulnerabilities.
# This configuration permits essential application and MongoDB classes to be deserialized
# from YAML without completely disabling Ruby's deserialization security features.
# Required since Ruby 3.1, which made YAML deserialization more restrictive by default.
Psych::ClassLoader::ALLOWED_PSYCH_CLASSES = [
  Date,
  Time,
  Symbol,
  'SicCode',
  'BenefitSponsors::Organizations::ExemptOrganization',
  'BSON::Document',
  'BSON::ObjectId'
].freeze

module Psych
  # modify the class loader to allow for additional data types as yaml columns
  class ClassLoader
    ALLOWED_PSYCH_CLASSES = [].freeze unless defined? ALLOWED_PSYCH_CLASSES
    # modify the class loader to allow for additional data types as yaml columns
    class Restricted < ClassLoader
      def initialize(classes, symbols)
        allowed_classes = Psych::ClassLoader::ALLOWED_PSYCH_CLASSES.map do |klass|
          klass.is_a?(String) ? klass : klass.to_s
        end

        @classes = classes + allowed_classes
        @symbols = symbols
        super()
      end
    end
  end
end

module Enroll
  class Application < Rails::Application

    config.load_defaults 7.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.autoload_paths += ["#{config.root}/lib", "#{config.root}/app/notices", "#{config.root}/app/jobs"]
    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.available_locales = [:am, :en, :es, :ja]
    config.i18n.default_locale = :en

    # Do not swallow errors in after_commit/after_rollback callbacks.
    # config.active_record.raise_in_transactional_callbacks = true
    config.assets.enabled = true
    config.assets.paths << "#{Rails.root}/app/assets/info"

    I18n::Backend::Simple.include I18n::Backend::Fallbacks
    config.i18n.fallbacks = [I18n.default_locale, {'am' => 'en', 'es' => 'en', 'ja' => 'en'}]
    config.paths.add "app/api", glob: "**/*.rb"
    config.autoload_paths += Dir["#{Rails.root}/app/api/api/*/*"]

    #Thanks to Wojtek Kruszewski: https://gist.github.com/WojtekKruszewski
    config.log_tags = [    #'-anything',
      lambda { |req|
        SessionTaggedLogger.extract_session_id_from_request(req)
      }
    ]

    # Skip AMQP subscriptions for console - they're not needed for interactive sessions
    # and can cause significant delays due to RabbitMQ connection timeouts
    unless Rails.env.test? || defined?(Rails::Console)
      config.acapi.add_subscription("Events::ResidencyVerificationRequestsController")
      config.acapi.add_subscription("Events::SsaVerificationRequestsController")
      config.acapi.add_subscription("Events::VlpVerificationRequestsController")
      config.acapi.add_async_subscription("Subscribers::DateChange")
      config.acapi.add_async_subscription("Subscribers::NfpStatementHistory")
      config.acapi.add_async_subscription("Subscribers::SsaVerification")
      config.acapi.add_async_subscription("Subscribers::LawfulPresence")
      config.acapi.add_async_subscription("Subscribers::LocalResidency")
      config.acapi.add_async_subscription("Subscribers::FamilyApplicationCompleted")
      config.acapi.add_async_subscription("Subscribers::IamAccountCreation")
      config.acapi.add_async_subscription("Subscribers::NotificationSubscriber")
      config.acapi.add_async_subscription("Subscribers::DefaultGaChanged")
      config.acapi.add_async_subscription("Subscribers::ShopBinderEnrollmentsTransmissionAuthorized")
      config.acapi.add_async_subscription("Subscribers::ShopRenewalTransmissionAuthorized")
      config.acapi.add_async_subscription("Subscribers::ShopInitialEmployerQuietPeriodEnded")
      config.acapi.add_async_subscription("Subscribers::PolicyTerminationsSubscriber")
      config.acapi.add_async_subscription("Subscribers::EmployeeEnrollmentInvitationsSubscriber")
      config.acapi.add_async_subscription("Subscribers::EmployeeInitialEnrollmentInvitationsSubscriber")
      config.acapi.add_async_subscription("Subscribers::EmployeeRenewalInvitationsSubscriber")
      config.acapi.add_amqp_worker("TransportProfiles::Subscribers::TransportArtifactSubscriber")
      config.acapi.add_async_subscription("Notifier::NotificationSubscriber")
    end
  end
end
