require File.join(Rails.root, "app", "data_migrations", "update_primary_phone_to_secondary_address")
# This rake task is to move phone number associated to primary office location to the secondary office location
# RAILS_ENV=production bundle exec rake migrations:update_primary_phone_to_secondary_address
namespace :migrations do
  desc "update_primary_phone_to_secondary_address"
  UpdatePrimaryPhoneToSecondaryAddress.define_task :update_primary_phone_to_secondary_address => :environment
end