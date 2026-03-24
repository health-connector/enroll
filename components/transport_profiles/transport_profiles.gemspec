$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "transport_profiles/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "transport_profiles"
  s.version     = TransportProfiles::VERSION
  s.authors     = ["Trey Evans"]
  s.email       = ["lewis.r.evans@gmail.com"]
  s.homepage    = "https://github.com/ideacrew"
  s.summary     = "Transport gateway credentials and providers"
  s.description = "Transport gateway credentials and providers"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]

  s.add_dependency 'rails', '~> 8.1', '>= 8.1.2'
  s.add_dependency 'mongoid', '~> 9'
  s.add_dependency 'transport_gateway'
  s.add_dependency 'acapi'
  s.add_dependency 'symmetric-encryption', '~> 4.6.0'
  s.add_dependency 'rubyzip', '>=1.3.0'
  s.add_dependency 'rack', '>= 2.2.14'
  s.add_dependency 'net-imap',  '>= 0.4.20'

  s.add_development_dependency 'rspec-rails', '~> 5.0.1'
  s.add_development_dependency 'shoulda-matchers'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'rspec'
  s.metadata['rubygems_mfa_required'] = 'true'
end
