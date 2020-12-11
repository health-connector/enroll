source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.6.5'

gem "benefit_markets", path: "components/benefit_markets"
gem "benefit_sponsors", path: "components/benefit_sponsors"

gem 'aasm', '~> 4.8'
gem 'acapi',              git: "https://github.com/dchbx/acapi.git", branch: 'master'
gem 'addressable',              '~> 2.3'
gem 'animate-rails', '~> 1.0.10'
gem 'aws-sdk', '~> 2.2.4'
gem 'bcrypt', '~> 3.1'
gem 'browser', '2.7.0'
gem 'bson', '~> 4.3'
gem 'carrierwave-mongoid', '~> 1.2', :require => 'carrierwave/mongoid'
gem 'chosen-rails'
gem 'ckeditor', '~> 4.2.4'
gem 'coffee-rails', '~> 4.2.2'
gem 'combine_pdf', '~> 1.0'
gem 'config', '~> 2.0'
gem 'curl', '~> 0.0.9'
gem 'devise',  '~> 4.5'
gem 'effective_datatables', path: './project_gems/effective_datatables-2.6.14'
gem 'haml', '~> 5.0'
gem 'httparty', '~> 0.16'
gem 'i18n', '~> 1.5.1'
gem 'interactor', '~> 3.0'
gem 'interactor-rails', '~> 2.2'
gem 'jbuilder', '~> 2.7'
gem 'jquery-datatables-rails', '3.4.0'
gem 'jquery-turbolinks'
gem 'jquery-ui-rails'
gem 'kaminari', '~> 0.17.0'
gem 'language_list', '~> 1.1'
gem 'maskedinput-rails', '~> 1.4'
gem 'money-rails', '~> 1.13'
gem 'mongo', '~> 2.6'
gem 'mongo_session_store', '~> 3.1'
gem 'mongoid', '~> 7.0.2'
gem 'mongoid-autoinc', '~> 6.0'
gem 'mongoid-history', '~> 0.8'
#gem 'mongoid-versioning'
#gem 'mongoid_rails_migrations', git: 'https://github.com/adacosta/mongoid_rails_migrations.git', branch: 'master'
gem 'mongoid_rails_migrations', '~> 1.2'
gem 'mongoid_userstamp',        '~> 0.4', :path => "./project_gems/mongoid_userstamp-0.4.0"
gem 'nokogiri', '~> 1.10.8'
gem 'nokogiri-happymapper', '~> 0.8.0', :require => 'happymapper'
gem 'non-stupid-digest-assets', '~> 1.0', '>= 1.0.9'
gem "notifier",           path: "components/notifier"
gem 'openhbx_cv2', git: 'https://github.com/dchbx/openhbx_cv2.git', branch: 'master'
gem 'resource_registry',  git:  'https://github.com/ideacrew/resource_registry.git', branch: 'master'
gem 'prawn', :git => 'https://github.com/prawnpdf/prawn.git', :ref => '8028ca0cd2'
gem 'pundit', '~> 1.0.1'
gem 'rails', '5.2.3'
gem 'recurring_select', :git => 'https://github.com/brianweiner/recurring_select'
gem "recaptcha", '4.3.1', require: 'recaptcha/rails'
gem 'redcarpet', '3.4'
gem 'redis-rails', '~> 5.0.2'
gem 'resque', '~> 2.0'
gem 'roo', '~> 2.1.0'
gem 'ruby-saml', '~> 1.3.0'
gem 'slim', '~> 3.0.8'
gem 'slim-rails'
gem 'simple_calendar', :git => 'https://github.com/harshared/simple_calendar.git'
gem "sponsored_benefits", path: "components/sponsored_benefits"
gem 'symmetric-encryption', '~> 3.9.1'
gem 'therubyracer', platforms: :ruby
gem "transport_gateway",  path: "components/transport_gateway"
gem "transport_profiles", path: "components/transport_profiles"
gem 'turbolinks', '~> 5'
#gem 'sprockets', '~> 3.6.0'
#gem 'sprockets-rails'
gem 'uglifier', '>= 4', require: 'uglifier'
gem 'virtus', '~> 1.0'
gem 'wicked_pdf', '1.1.0'
gem 'wkhtmltopdf-binary-edge', '~> 0.12.3.0'
gem 'webpacker', '~> 4.0.2'
gem 'rubyXL'

#######################################################
# Removed gems
#######################################################
#
# gem 'acapi', path: '../acapi'
# gem 'bh'
# gem 'devise_ldap_authenticatable', '~> 0.8.1'
# gem 'highcharts-rails', '~> 4.1', '>= 4.1.9'
# gem 'kaminari-mongoid' #DEPRECATION WARNING: Kaminari Mongoid support has been extracted to a separate gem, and will be removed in the next 1.0 release.
# gem 'mongoid-encrypted-fields', '~> 1.3.3'
# gem 'mongoid-history', '~> 5.1.0'
# gem 'rypt', '0.2.0'
# gem 'rocketjob_mission_control', '~> 3.0'
# gem 'rails_semantic_logger'
# gem 'rocketjob', '~> 3.0'
#
#######################################################

group :doc do
  gem 'sdoc', '~> 0.4.0'
end

group :development do
  gem "certified"
  gem 'overcommit'
  gem 'rubocop', "0.61.1", require: false
  gem 'rubocop-git'
  gem 'web-console', '2.3.0'
end

group :development, :test do
  gem 'capistrano', '3.3.5'
  gem 'capistrano-rails', '1.4'
  gem 'climate_control', '~> 0.2.0'
  gem 'email_spec', '~> 2'
  gem 'factory_bot_rails', '~> 4.11'
  gem 'forgery', '~> 0.7.0'
  gem 'parallel_tests', '2.26.2'
  gem 'puma', '~> 3.12.4'
  gem 'railroady', '~> 1.5.3'
  gem 'rspec-rails'
  gem 'rspec_junit_formatter', '0.2.3'
  gem 'spring', '1.6.3'
  gem 'yard', '~> 0.9.5', require: false
  gem 'yard-mongoid', '~> 0.1.0', require: false
end

group :test do
  gem 'action_mailer_cache_delivery', '~> 0.3.7'
  gem 'capybara', '~> 3.12'
  gem 'capybara-screenshot', '~> 1.0.18'
  gem 'cucumber'
  gem 'database_cleaner', '~> 1.7'
  gem 'fakeredis', '~> 0.7.0', :require => 'fakeredis/rspec'
  gem 'mongoid-rspec', '~> 4'
  gem 'selenium-webdriver', '3.14.0'
  gem 'webdriver'
  gem 'rspec-instafail', '~> 1'
  gem 'rspec-benchmark'
  gem 'ruby-progressbar', '~> 1.7'
  gem 'shoulda-matchers', '3.1.1'
  gem 'simplecov', '0.14.1', :require => false
  gem 'test-prof', '0.5.0'
  gem 'warden'
  gem 'watir'
  gem 'webdrivers', '~> 3.0'
  gem 'webmock'
end

group :production do
  gem 'eye', '0.8'
  gem 'newrelic_rpm', '~> 5.0'
  gem 'unicorn', '~> 4.8.3'
end
