require File.join(Rails.root, "app", "data_migrations", "golden_seed")
# This rake task should be used in conjunction with the database seed with
# employers for testing
# Rake takes in benefit_sponsorship_id list and and coverage_start_on and end_on dates
# and updates the coverage start/end on and open enrollment start/end on
# RAILS_ENV=production bundle exec rake migrations:golden_seed benefit_sponsorship_ids="1111, 112222, 3333"

namespace :migrations do
  desc "Seeds database with test data for functional testing."
  GoldenSeed.define_task :golden_seed => :environment
end
