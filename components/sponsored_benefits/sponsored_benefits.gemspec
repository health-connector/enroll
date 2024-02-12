$LOAD_PATH.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "sponsored_benefits/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "sponsored_benefits"
  s.version     = SponsoredBenefits::VERSION
  s.authors     = ["raghuram"]
  s.email       = ["raghuramg83@gmail.com"]
  s.homepage    = "https://github.com/ideacrew"
  s.summary     = "Summary of SponsoredBenefits."
  s.description = "Description of SponsoredBenefits."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]

  s.add_dependency "rails", "5.2.8.1"
  s.add_dependency "slim", "~> 3.0.8"
  s.add_dependency "mongoid", "7.0.2"
  s.add_dependency "aasm", "~> 4.8.0"
  s.add_dependency 'config'
  s.add_dependency 'symmetric-encryption', '~> 3.6.0'
  s.add_dependency 'roo', '~> 2.1.0'
  s.add_dependency 'dry-types'
  s.add_dependency 'dry-schema', '~> 1.0'
  s.add_dependency 'dry-validation', '~> 1.0'
  s.add_dependency 'dry-initializer'
  s.add_dependency 'dry-auto_inject', '0.6.1'
  s.add_dependency 'dry-container'
  s.add_dependency 'dry-struct'
  s.add_dependency 'dry-monads'

  s.test_files = Dir["spec/**/*"]

  s.add_development_dependency "rspec-rails"
  s.add_development_dependency 'shoulda-matchers'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'factory_girl_rails'
  s.add_development_dependency 'forgery'
  s.add_development_dependency "rspec-benchmark"
end