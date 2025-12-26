# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.4.7'

gem "benefit_markets",    path: "components/benefit_markets"
gem "benefit_sponsors",   path: "components/benefit_sponsors"
gem "notifier",           path: "components/notifier"
gem "sponsored_benefits", path: "components/sponsored_benefits"
gem "transport_gateway",  path: "components/transport_gateway"
gem "transport_profiles", path: "components/transport_profiles"
gem 'aca_entities',       git: 'https://github.com/ideacrew/aca_entities.git', branch: 'trunk'

gem 'aasm', '~> 4.8.0'
gem 'acapi', git: "https://github.com/ideacrew/acapi.git", branch: 'trunk'
gem 'addressable', '2.8.0'
gem 'animate-rails', '~> 1.0.10'
gem 'aws-sdk', '~> 3.2'
gem 'bcrypt', '~> 3.1'
gem 'bootstrap-multiselect-rails', '~> 0.9.9'
# TODO: Validate this gem if it's being used.
# gem 'bootstrap-slider-rails', '9.8.0'
gem 'browser', '2.7.0'
gem 'bson', '~> 4.3'
gem 'carrierwave-mongoid', :require => 'carrierwave/mongoid'
gem 'chosen-rails'
gem 'ckeditor', '4.2.4'
gem 'coffee-rails', '~> 5.0.0'
gem 'combine_pdf'
gem 'devise',  '~> 4.5'
gem 'matrix'
gem 'effective_datatables', path: './project_gems/effective_datatables-2.6.14'
gem 'haml'
gem 'httparty'
gem 'i18n', '~> 1.5'
gem 'interactor', '~> 3.1.2'
gem 'interactor-rails', '2.2.1'
gem 'jbuilder', '~> 2.7'
# gem 'jquery-datatables-rails', '3.4.0'
gem 'jquery-rails', '~> 4.3'
gem 'jquery-turbolinks'
gem 'jquery-ui-rails', '>= 8.0.0'
gem 'kaminari', '= 1.2.1'
gem 'kaminari-mongoid'
gem 'kaminari-actionview'
gem 'language_list', '~> 1.1.0'
gem 'mail', '~> 2.7'
gem 'maskedinput-rails'
gem 'money-rails', '~> 1.13'
gem 'mongo_session_store', '~> 3.1'
gem 'mongoid', '~> 8.1.5'
gem 'mongoid-autoinc', '~> 6.0'
gem 'mongoid-history', '~> 0.8'
# gem 'mongoid-versioning'
gem 'mongoid_rails_migrations', '1.2.1'
gem 'nokogiri', '~> 1.18.9'
gem 'nokogiri-happymapper', '~> 0.8.0', :require => 'happymapper'
gem 'mongoid_userstamp', '~> 0.4', :path => "./project_gems/mongoid_userstamp-0.4.0"

gem 'non-stupid-digest-assets', '~> 1.0', '>= 1.0.9'
gem 'openhbx_cv2', git: 'https://github.com/ideacrew/openhbx_cv2.git', branch: 'trunk'
gem 'resource_registry',  git:  'https://github.com/ideacrew/resource_registry.git', tag: 'v0.10.1'
gem 'prawn', :git => 'https://github.com/prawnpdf/prawn.git', :ref => '8028ca0cd2'
gem 'pundit', '~> 2.0'
gem 'rails', '~> 8.0.0'
gem 'rails-i18n', '~> 8.0.0'
gem 'recurring_select', '~> 3.0'
gem "recaptcha", '~> 4.13', require: 'recaptcha/rails'
gem 'redis', '>= 4.0'
gem 'hiredis' # Optional but recommended for performance in Rails 8
gem 'rack', '>= 3.2.3'
gem 'resque'
gem 'sinatra', '>= 4.2.0' # update sub-dependency for resque
gem 'net-imap', '>= 0.4.20'
gem 'rexml',  '>= 3.3.9'
gem 'roo', '~> 2.10'
gem 'ruby-saml', '~> 1.18.0'
gem 'slim', '~> 5.2'
gem 'slim-rails'
gem 'sprockets', '~> 4.2'
gem 'symmetric-encryption', '~> 4.6.0'
gem 'turbolinks', '~> 5'
gem 'uglifier', '>= 4', require: 'uglifier'
gem 'virtus'
gem 'wicked_pdf', '2.1.0'
gem 'wkhtmltopdf-binary-edge', '~> 0.12.3.0'
gem 'shakapacker', '~> 7.0'
gem 'rubyXL'
gem 'holidays', '~> 8.6'
gem 'thor', '>= 1.4.0'

#arm64 mac support
gem 'ffi', '1.15.5'
gem 'kostya-sigar', '2.0.10'
# gem 'mini_racer', '0.6.4'
gem 'bigdecimal', '~> 3.0'
gem 'loofah',     '~> 2.23', '>= 2.23.1'
gem 'dry-container', '0.9'
gem 'haml-rails', '~> 2.0'
gem 'sassc',                    '~> 2.0'
gem 'sass-rails', '~> 6.0'
gem 'config',                   '~> 5.5', '>= 5.5.2'
gem 'rack-cors'
gem 'puma', '~> 6.6.0'
gem "observer"
gem "openssl"

#######################################################
# Removed gems
#######################################################
#
# gem 'acapi', path: '../acapi'
# gem 'bh'
# gem 'devise_ldap_authenticatable', '~> 0.8.1'
# gem 'highcharts-rails', '~> 4.1', '>= 4.1.9'
# gem 'mongoid-encrypted-fields', '~> 1.3.3'
# gem 'mongoid-history', '~> 5.1.0'
# gem 'rypt', '0.2.0'
# gem 'rocketjob_mission_control', '~> 3.0'
# gem 'rails_semantic_logger'
# gem 'rocketjob', '~> 3.0'
#
#######################################################

group :development do
  gem "certified"
  gem 'overcommit'
  gem 'rubocop', require: false
  gem 'rubocop-rspec'
  gem 'rubocop-git'
  gem 'web-console', '>= 3'
  gem 'next_rails'
end

group :development, :test do
  gem 'brakeman'
  gem 'capistrano', '3.3.5'
  gem 'capistrano-rails', '1.1.6'
  gem 'climate_control', '0.2.0'
  gem 'email_spec', '~> 2'
  gem 'factory_bot_rails', '~> 6.4', '>= 6.4.4'
  gem 'forgery'
  gem 'parallel_tests', '2.26.2'
  gem 'rails-controller-testing'
  gem 'railroady', '~> 1.5.3'
  gem 'rspec-rails', '~> 7.1'
  gem 'rdoc', '~> 6.3.4'
  gem 'rspec_junit_formatter', '0.2.3'
  gem 'spring'
  gem 'yard', '~> 0.9.5', require: false
  gem 'yard-mongoid', '~> 0.1.0', require: false
  gem 'sdoc',  '~> 1.0'
  gem 'pry-byebug'
end

group :test do
  gem 'action_mailer_cache_delivery', '0.4'
  gem 'capybara',                     '~> 3.39'
  gem 'capybara-screenshot',          '~> 1.0.18'
  gem 'cucumber-rails', '~> 3.0', '>= 3.0.1', :require => false
  gem 'database_cleaner-mongoid', '~> 2.0', '>= 2.0.1'
  gem 'fakeredis', :require => 'fakeredis/rspec'
  gem 'mongoid-rspec', '~> 4.2'
  gem 'rspec-instafail'
  gem 'rspec-benchmark'
  gem 'ruby-progressbar', '~> 1.7'
  gem 'shoulda-matchers', '>= 4.0.0'
  gem 'simplecov', '~> 0.22.0',  :require => false
  gem 'test-prof', '~> 1.3'
  gem 'warden'
  gem 'watir',                        '~> 6.18.0'
  gem 'webdrivers', '~> 5.3.1'
  gem 'webmock'
end

group :production do
  gem 'eye', '0.10.0'
  gem 'newrelic_rpm', '~> 9.6'
end