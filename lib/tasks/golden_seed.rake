require File.join(Rails.root, "app", "data_migrations", "golden_seed_update_benefit_application_dates")
require File.join(Rails.root, "app", "data_migrations", "golden_seed_shop")
# golden_seed_update_benefit_application_dates
# This rake task should be used in conjunction with the database seed with employers for testing
# Rake takes in default employer list from seed
# and takes coverage_start_on and end_on dates to form effective period
# RAILS_ENV=production bundle exec rake migrations:golden_seed_update_benefit_applications coverage_start_on="01/01/2020" coverage_end_on "05/01/2020"

# golden_seed_shop
# This rake task generates employers, employees, and dependents for specific, pre existing plans and carriers.
# and takes coverage_start_on and end_on dates to form effective period
# RAILS_ENV=production bundle exec rake migrations:golden_seed_shop

namespace :migrations do
  desc "Generates Employers, Employees, and Dependents from existing carriers and plans. Can be run on any environment without affecting existing data. Uses existing carreirs/plans."
  GoldenSeedSHOP.define_task :golden_seed_shop => :environment
  desc "Updates effective on periods for employer benefit applications from employer list a specific dump. Can be enhanced to ingest employer legal name list."
  GoldenSeedUpdateBenefitApplicationDates.define_task :golden_seed_update_benefit_applications => :environment
end
