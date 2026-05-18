require File.join(Rails.root, "app", "data_migrations", "remove_plan_offerings_for_employer")
#RAILS_ENV=production bundle exec rake migrations:remove_plan_offerings fein=5645667 aasm_state=active carrier_profile_id='53237210eb899a4603000321'

namespace :migrations  do
  desc "removing plans for er"
  RemovePlanOfferingsForEmployer.define_task :remove_plan_offerings => :environment
end
 