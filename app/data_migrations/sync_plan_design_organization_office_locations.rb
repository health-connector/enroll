# frozen_string_literal: true

require File.join(Rails.root, "lib/mongoid_migration_task")

# Copies each client employer's current office locations onto the broker's plan design organizations
# for that employer, fixing quotes built on an address the employer has since changed
class SyncPlanDesignOrganizationOfficeLocations < MongoidMigrationTask
  def migrate
    SponsoredBenefits::Organizations::PlanDesignOrganization.where(:sponsor_profile_id.ne => nil).no_timeout.each do |pdo|
      sync(pdo)
    rescue StandardError => e
      log("Could not sync #{pdo.legal_name} (#{pdo.id}): #{e.message}")
    end
  end

  private

  def sync(pdo)
    employer_profile = BenefitSponsors::Organizations::Organization.where(:"profiles._id" => pdo.sponsor_profile_id).first&.employer_profile
    return if employer_profile.blank? || pdo.office_addresses_match?(employer_profile.office_locations)

    pdo.update!(office_locations: employer_profile.office_locations.map { |location| location.attributes.deep_dup })
    log("Synced office locations for #{pdo.legal_name} (#{pdo.id})")
  end

  def log(message)
    puts message unless Rails.env.test?
  end
end
