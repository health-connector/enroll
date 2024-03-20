# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require 'spec_helper'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'shoulda/matchers'
require 'webmock/rspec'

WebMock.allow_net_connect!

require 'kaminari'
require File.expand_path('app/models/services/checkbook_services')

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
  end
end
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

RSpec.configure do |config|
  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  load "#{Rails.root}db/seedfiles/english_translations_seed.rb"
  DatabaseCleaner.strategy = :truncation, {:except => %w[translations]}

  config.after(:example, :dbclean => :after_each) do
    DatabaseCleaner.clean
#    TimeKeeper.set_date_of_record_unprotected!(Date.current)
  end

  config.around(:example, :dbclean => :around_each) do |example|
    DatabaseCleaner.clean
    example.run
    DatabaseCleaner.clean
    TimeKeeper.set_date_of_record_unprotected!(Date.current)
  end

  config.include ModelMatcherHelpers, :type => :model
  config.include Devise::Test::ControllerHelpers, :type => :controller
  config.include Devise::Test::ControllerHelpers, :type => :view
  config.include Devise::Test::IntegrationHelpers, type: :feature
  config.extend ControllerMacros, :type => :controller #real logins for integration testing
  config.include ControllerHelpers, :type => :controller #stubbed logins for unit testing
  config.include FactoryBot::Syntax::Methods
  config.include FederalHolidaysHelper
  config.include Config::AcaModelConcern

  config.infer_spec_type_from_file_location!

  config.include Capybara::DSL

end

# error: ThreadError: already initialized
# solution found here https://github.com/rails/rails/issues/34790#issuecomment-450502805
# In case there are still poor souls on Rails 4.2 with Ruby 2.6/2.7, this is the full file working for my team, required from rails_helper.rb.

# From https://github.com/rails/rails/issues/34790
#
# This is required because of an incompatibility between Ruby 2.6 and Rails 4.2, which the Rails team is not going to fix.

rb_version = Gem::Version.new(RUBY_VERSION)

if rb_version >= Gem::Version.new('2.6') && Gem::Version.new(Rails.version) < Gem::Version.new('5')
  raise "Needed class is not defined yet, try requiring this file later." unless defined?(::ActionController::TestResponse)

  if rb_version >= Gem::Version.new('2.7')
    puts "Using #{__FILE__} for Ruby 2.7."

    module ActionController
      class TestResponse < ActionDispatch::TestResponse
        def recycle!
          @mon_data = nil
          @mon_data_owner_object_id = nil
          initialize
        end
      end
    end

    module ActionController
      class LiveTestResponse < ActionController::Live::Response
        def recycle!
          @body = nil
          @mon_data = nil
          @mon_data_owner_object_id = nil
          initialize
        end
      end
    end

  else
    puts "Using #{__FILE__} for Ruby 2.6."

    module ActionController
      class TestResponse < ActionDispatch::TestResponse
        def recycle!
          @mon_mutex = nil
          @mon_mutex_owner_object_id = nil
          initialize
        end
      end
    end

    module ActionController
      class LiveTestResponse < ActionController::Live::Response
        def recycle!
          @body = nil
          @mon_mutex = nil
          @mon_mutex_owner_object_id = nil
          initialize
        end
      end
    end

  end
else
  puts "#{__FILE__} no longer needed."
end
