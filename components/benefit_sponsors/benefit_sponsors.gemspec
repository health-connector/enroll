$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "benefit_sponsors/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "benefit_sponsors"
  s.version     = BenefitSponsors::VERSION
  s.authors     = ["Dan Thomas"]
  s.email       = ["dan.thomas@dc.gov"]
  s.homepage    = "https://github.com/ideacrew"
  s.summary     = "Summary of BenefitSponsors."
  s.description = "Description of BenefitSponsors."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 7.2"
  s.add_dependency "slim", '~> 5.2'
  s.add_dependency "mongoid", '~> 8.1.5'
  # s.add_dependency 'mongoid-multitenancy', '~> 1.2'
  s.add_dependency "aasm", "~> 4.8.0"
  s.add_dependency 'config', '~> 5.5', '>= 5.5.2'
  s.add_dependency 'symmetric-encryption', '~> 4.6.0'
  s.add_dependency 'pundit', '~> 2.0'
  s.add_dependency 'roo', '~> 2.10'
  s.add_dependency 'money-rails', '~> 1.13'
  s.add_dependency 'virtus', '~> 1.0.5'
  s.add_dependency 'active_model_serializers'
  # s.add_dependency 'devise', '~> 3.5.4'
  s.add_dependency 'devise', '~> 4.5'
  s.add_dependency 'language_list', '~> 1.1.0'
  s.add_dependency 'mongoid-autoinc', '~> 6.0'
  s.add_dependency 'interactor', '3.1.2'
  s.add_dependency 'interactor-rails', '2.2.1'
  s.add_dependency 'browser', '2.7.0'
  s.add_dependency 'dry-schema', '~> 1.0'
  s.add_dependency 'dry-validation', '~> 1.0'
  s.add_dependency 'dry-initializer'
  s.add_dependency 'dry-auto_inject', '0.6.1'
  s.add_dependency 'dry-container'
  s.add_dependency 'dry-struct'
  s.add_dependency 'dry-monads'
  s.add_dependency 'rack', '>= 2.2.13'
  s.add_dependency 'net-imap',  '>= 0.4.20'

  s.test_files = Dir["spec/**/*"]

  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "mongoid-rspec"
  s.add_development_dependency 'shoulda-matchers'
  s.add_development_dependency 'rubocop-rspec',             '~> 1.31'
  s.add_development_dependency 'database_cleaner-mongoid'
  s.add_development_dependency 'capybara', '2.6.2'
  s.add_development_dependency 'factory_bot_rails',         '~> 4'
  s.add_development_dependency 'test-prof', '~> 1.3'
  s.add_development_dependency 'forgery'
  s.add_development_dependency 'mongoid_rails_migrations'
  s.add_development_dependency 'rails-perftest'
  s.add_development_dependency 'climate_control',           '~> 0.2.0'
end
