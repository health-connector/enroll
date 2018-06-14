# To Generate a report of the EE and Conversion ERs effected by the new hire effective date policy 
# RAILS_ENV=production bundle exec rake migrations:new_hire_effective_on_report

require File.join(Rails.root, "app", "data_migrations", "new_hire_effective_on_report")

namespace :migrations do
  desc "report to check the new hire effective policy"
  NewHireEffectiveOnReport.define_task :new_hire_effective_on_report => :environment
end