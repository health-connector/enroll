# frozen_string_literal: true

require File.join(Rails.root, "app", "data_migrations", "fix_prospect_employer_placeholder_county")
# This rake task fixes prospect employers whose county was saved as the dropdown placeholder text
# RAILS_ENV=production bundle exec rake migrations:fix_prospect_employer_placeholder_county
namespace :migrations do
  desc "fix prospect employers with a placeholder county"
  FixProspectEmployerPlaceholderCounty.define_task :fix_prospect_employer_placeholder_county => :environment
end
