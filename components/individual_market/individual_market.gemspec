$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "individual_market/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "individual_market"
  s.version     = IndividualMarket::VERSION
  s.authors     = ["nks2109"]
  s.email       = ["nikhilks219@gmail.com"]
  s.homepage    = "https://github.com/ideacrew"
  s.summary     = "Summary of IndividualMarket."
  s.description = "This engine provides individual market functionality for a enroll application"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.11"

  s.add_development_dependency "sqlite3"
end
