require File.join(Rails.root, "app", "data_migrations", "cancel_plan_year")

# RAILS_ENV=production bundle exec rake migrations:cancel_plan_year feins='043576862 474730282 042104074 042876321 043280601 043158592 043101467 270611091 300249279 274282797' plan_year_state="renewing_enrolled"

namespace :migrations do
  desc "cancel plan year"
  CancelPlanYear.define_task :cancel_plan_year => :environment
end 
