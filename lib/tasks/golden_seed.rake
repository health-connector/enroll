require File.join(Rails.root, "app", "data_migrations", "golden_seed")
# This rake tasks will generate the following data without removing anything from the database:
# Employers
# Census Employees, Families, Family Members/Dependents etc.
# TODO: Update this to take CSV as source file
# RAILS_ENV=production bundle exec rake migrations:golden_seed

namespace :migrations do
  desc "Seeds database with test data for functional testing."
  GoldenSeed.define_task :golden_seed => :environment
end