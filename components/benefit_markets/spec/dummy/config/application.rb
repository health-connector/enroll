require File.expand_path('../boot', __FILE__)

# Pick the frameworks you want:
# require 'rails/all'
# require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)
require "benefit_markets"

Psych::ClassLoader::ALLOWED_PSYCH_CLASSES = [Date, Time, Symbol].freeze

module Psych
  # modify the class loader to allow for additional data types as yaml columns
  class ClassLoader
    ALLOWED_PSYCH_CLASSES = [].freeze unless defined? ALLOWED_PSYCH_CLASSES
    # modify the class loader to allow for additional data types as yaml columns
    class Restricted < ClassLoader
      def initialize(classes, symbols)
        @classes = classes + Psych::ClassLoader::ALLOWED_PSYCH_CLASSES.map(&:to_s)
        @symbols = symbols
        super()
      end
    end
  end
end

module Dummy
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

  end
end

