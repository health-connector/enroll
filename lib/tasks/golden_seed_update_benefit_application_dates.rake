require File.join(Rails.root, "app", "data_migrations", "golden_seed_update_benefit_applications")
# This rake task should be used in conjunction with the database seed with employers for testing
# Rake takes in default employer list from seed
# and takes coverage_start_on and end_on dates to form effective period
# RAILS_ENV=production bundle exec rake migrations:golden_seed coverage_start_on="01/01/2020" coverage_end_on "05/01/2020"

namespace :migrations do
  desc "Updates effective on periods for employer benefit applications"
  GoldenSeedUpdateBenefitApplicationDates.define_task :golden_seed => :environment
end
