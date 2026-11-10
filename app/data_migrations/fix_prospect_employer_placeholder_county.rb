# frozen_string_literal: true

require File.join(Rails.root, "lib/mongoid_migration_task")

# Re-derives the county on prospect employers whose primary address saved the county dropdown's
# placeholder text instead of a county, which leaves their quotes unpriced
class FixProspectEmployerPlaceholderCounty < MongoidMigrationTask
  PLACEHOLDERS = ['Please provide a zip code', 'Zip code outside supported area'].freeze

  def migrate
    SponsoredBenefits::Organizations::PlanDesignOrganization.prospect_sponsors.where(
      :"office_locations.address.county".in => PLACEHOLDERS
    ).each do |organization|
      if organization.save(context: :prospect_entry)
        puts "Fixed county for #{organization.legal_name} (#{organization.id})" unless Rails.env.test?
      else
        puts "Could not fix #{organization.legal_name} (#{organization.id}): #{organization.errors.full_messages.join(', ')}" unless Rails.env.test?
      end
    end
  end
end
