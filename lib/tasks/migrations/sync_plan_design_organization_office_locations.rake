# frozen_string_literal: true

require File.join(Rails.root, "app", "data_migrations", "sync_plan_design_organization_office_locations")
# This rake task copies client employers' current office locations onto their brokers' plan design organizations
# RAILS_ENV=production bundle exec rake migrations:sync_plan_design_organization_office_locations
namespace :migrations do
  desc "sync broker plan design organization office locations with their employers"
  SyncPlanDesignOrganizationOfficeLocations.define_task :sync_plan_design_organization_office_locations => :environment
end
