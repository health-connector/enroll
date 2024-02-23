source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.7.6'

gem "benefit_markets", path: "components/benefit_markets"
gem "benefit_sponsors", path: "components/benefit_sponsors"
gem "notifier",           path: "components/notifier"
gem "sponsored_benefits", path: "components/sponsored_benefits"
gem "transport_gateway",  path: "components/transport_gateway"
gem "transport_profiles", path: "components/transport_profiles"

gem 'aasm', '~> 4.8.0'
gem 'acapi', git: "https://github.com/ideacrew/acapi.git", branch: 'trunk'
gem 'addressable', '2.8.0'
gem 'animate-rails', '~> 1.0.10'
gem 'aws-sdk', '2.2.4'
gem 'bcrypt', '~> 3.1'
gem 'bootstrap-multiselect-rails', '~> 0.9.9'
gem 'bootstrap-slider-rails', '9.8.0'
gem 'browser', '2.7.0'
gem 'bson', '~> 4.3'
gem 'carrierwave-mongoid', :require => 'carrierwave/mongoid'
gem 'chosen-rails'
gem 'ckeditor'
gem 'coffee-rails', '~> 4.2.2'
gem 'combine_pdf'
gem 'curl'
gem 'devise',  '~> 4.5'
gem 'effective_datatables', path: './project_gems/effective_datatables-2.6.14'
gem 'haml'
gem 'httparty'
gem 'i18n', '0.9.5'
gem 'interactor', '3.1.0'
gem 'interactor-rails', '2.2.1'
gem 'jbuilder', '~> 2.0'
gem 'jquery-datatables-rails', '3.4.0'
gem 'jquery-rails', '~> 4.3'
gem 'jquery-turbolinks'
gem 'jquery-ui-rails'
gem 'kaminari', '0.17.0'
gem 'language_list', '~> 1.1.0'
gem 'mail', '2.6.3'
gem 'maskedinput-rails'
gem 'money-rails', '~> 1.10.0'
gem 'mongo', '~> 2.6'
gem 'mongo_session_store', '~> 3.1'
gem 'mongoid', '~> 7.0.2'
gem 'mongoid-autoinc', '~> 6.0'
gem 'mongoid-history', '~> 0.8'
gem 'mongoid-versioning'
gem 'mongoid_rails_migrations', '1.2.1'
gem 'nokogiri', '1.13.10'
gem 'nokogiri-happymapper', '~> 0.8.0', :require => 'happymapper'
gem 'mongoid_userstamp', '~> 0.4', :path => "./project_gems/mongoid_userstamp-0.4.0"
gem 'non-stupid-digest-assets', '~> 1.0', '>= 1.0.9'
gem 'openhbx_cv2', git: 'https://github.com/ideacrew/openhbx_cv2.git', branch: 'trunk'
gem 'resource_registry',  git:  'https://github.com/ideacrew/resource_registry.git', branch: 'trunk'
gem 'prawn', :git => 'https://github.com/prawnpdf/prawn.git', :ref => '8028ca0cd2'
gem 'pundit', '~> 1.0.1'
gem 'rails', '5.2.8.1'
gem 'rails-i18n', '5.1.3'
gem 'recurring_select', '~> 3.0'
gem "recaptcha", '4.3.1', require: 'recaptcha/rails'
gem 'redcarpet', '3.4.0'
gem 'redis-rails'
gem 'resque'
gem 'roo', '~> 2.1.0'
gem 'ruby-saml', '~> 1.3'
gem 'slim', '~> 3.0.8'
gem 'slim-rails'
gem 'simple_calendar', :git => 'https://github.com/harshared/simple_calendar'
gem 'sprockets', '~> 3.5', '>= 3.5.2'
gem 'symmetric-encryption', '~> 3.6.0'
gem 'turbolinks', '~> 5'
gem 'uglifier', '>= 1.3.0', require: 'uglifier'
gem 'virtus'
gem 'wicked_pdf', '1.1.0'
gem 'wkhtmltopdf-binary-edge', '~> 0.12.3.0'
gem 'webpacker'
gem 'rubyXL'
gem 'holidays', '~> 8.6'

#arm64 mac support
gem 'ffi', '1.14.0'
gem 'kostya-sigar', '2.0.10'
gem 'mini_racer', '0.6.4'
gem 'bigdecimal', '1.3.5'
gem 'loofah', '~>2.19.1'
gem 'dry-container', '0.9'
gem 'haml-rails', '~> 1.0'
gem 'sassc',                    '~> 2.0'
gem 'sass-rails',               '~> 5'
gem 'config',                   '~> 2.0'

gem 'uri', '~> 0.13.0'

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
  gem 'rubocop', require: false
  gem 'rubocop-git'
  gem 'web-console', '2.3.0'
end

group :development, :test do
  gem 'brakeman'
  gem 'capistrano', '3.3.5'
  gem 'capistrano-rails', '1.1.6'
  gem 'climate_control', '0.2.0'
  gem 'email_spec', '2.0.0'
  gem 'factory_girl_rails', '4.6.0'
  gem 'forgery'
  gem 'parallel_tests', '2.26.2'
  gem 'puma', '4.3.6'
  gem 'railroady', '~> 1.5.2'
  gem 'rspec-rails', '~> 5.1.2'
  gem 'rspec_junit_formatter', '0.2.3'
  gem 'spring', '1.6.3'
  gem 'yard', '~> 0.9.5', require: false
  gem 'yard-mongoid', '~> 0.1.0', require: false
end

group :test do
  gem 'action_mailer_cache_delivery', '~> 0.3.7'
  gem 'capybara',                     '3.32.1'
  gem 'capybara-screenshot',          '~> 1.0.18'
  gem 'cucumber', '3.1.2'
  gem 'cucumber-rails', '2.0', :require => false
  gem 'database_cleaner', '1.5.3'
  gem 'fakeredis', :require => 'fakeredis/rspec'
  gem 'mongoid-rspec', '~> 4'
  gem 'rspec-instafail'
  gem 'rspec-benchmark'
  gem 'ruby-progressbar', '~> 1.7'
  gem 'shoulda-matchers', '3.1.1'
  gem 'simplecov', '0.14.1', :require => false
  gem 'test-prof', '0.5.0'
  gem 'warden'
  gem 'watir'
  gem 'webdrivers', '~> 5.3.1'
  gem 'webmock'
end

group :production do
  gem 'eye', '0.10.0'
  gem 'newrelic_rpm'
  gem 'unicorn', '~> 4.8.3'
end
