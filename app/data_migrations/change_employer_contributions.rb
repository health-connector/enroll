require File.join(Rails.root, "lib/mongoid_migration_task")

class ChangeEmployerContributions < MongoidMigrationTask
  def migrate
    organizations = ::BenefitSponsors::Organizations::Organization.where(fein: ENV['fein'])
    state = ENV['aasm_state'].to_s
    kind = ENV['coverage_kind'].to_s
    relationship_name = ENV['relationship_name'].to_s.sub(/_/, ' ').split.map{|w| w.camelcase}.join(" ")
    contribution_factor = ENV['contribution_factor'].to_f
    offered = ENV['is_offered']
    if organizations.size !=1
      raise 'Issues with fein'
    end
    if kind == "health"
      relationship = organizations.first.employer_profile.benefit_applications.where(aasm_state: state).first.benefit_packages.first.health_sponsored_benefit.sponsor_contribution.contribution_levels.where(:display_name => relationship_name).first
    elsif kind == "dental"
      relationship = organizations.first.employer_profile.benefit_applications.where(aasm_state: state).first.benefit_packages.first.dental_sponsored_benefit.sponsor_contribution.contribution_levels.where(:display_name => relationship_name).first
    else
      raise "Please provide accurate coverage kind"
    end
    relationship.update_attributes(:contribution_factor => contribution_factor, is_offered: offered)
  end
end
