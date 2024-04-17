module SponsoredBenefits
  module Organizations
    class BrokerAgencyProfile < Profile

      has_many :plan_design_organizations, class_name: "SponsoredBenefits::Organizations::PlanDesignOrganization", inverse_of: :broker_agency_profile
      accepts_nested_attributes_for :plan_design_organizations, class_name: "SponsoredBenefits::Organizations::PlanDesignOrganization"

      # All PlanDesignOrganizations that belong to this BrokerRole/BrokerAgencyProfile
      def employer_leads
      end

      class << self

        def find(id)
          SponsoredBenefits::Organizations::PlanDesignOrganization.find_by_owner(id).first
        end

        def office_locations(profile)
          return profile.office_locations if profile.respond_to?('office_locations')

          profile.organization.office_locations
        end

        def find_or_initialize_broker_profile(profile)
          organization = SponsoredBenefits::Organizations::Organization.find_or_initialize_by(fein: profile.fein)
          unless organization.persisted?
            organization.assign_attributes({
              hbx_id: profile.hbx_id,
              legal_name: profile.legal_name,
              dba: profile.dba,
              office_locations: office_locations(profile).map(&:attributes),
              broker_agency_profile: new # Prospect
            })
          end
          organization
        end

        def assign_employer(broker_agency:, employer:, office_locations:)
          broker_profile = find_or_initialize_broker_profile(broker_agency).broker_agency_profile

          plan_design_organization = SponsoredBenefits::Organizations::PlanDesignOrganization.find_by_owner_and_sponsor(broker_agency.id, employer.id)

          Rails.logger.info("*** plan_design_organization - #{plan_design_organization&.id&.to_s}, office_locations - #{office_locations&.count}")
          if plan_design_organization
            plan_design_organization.update_attributes!({
              has_active_broker_relationship: true,
              office_locations: office_locations(employer).map(&:attributes)
            })
          else
            broker_profile.plan_design_organizations.new({
              owner_profile_id: broker_agency._id,
              sponsor_profile_id: employer._id,
              office_locations: office_locations(employer).map(&:attributes),
              fein: employer.fein,
              legal_name: employer.legal_name,
              has_active_broker_relationship: true,
              sic_code: employer.sic_code,
            })
            Rails.logger.info("*** assign_employer - #{broker_profile.inspect}, attributes - #{broker_profile.attributes}")
            begin
              broker_profile.save!
            rescue StandardError => e
              Rails.logger.error("*** message - #{e.message}, attributes - #{e.backtrace}")
              raise e
            end
          end
          Rails.logger.info("*** completed running assign_employer")
        end

        def unassign_broker(broker_agency:, employer:)
          return if broker_agency.nil?
          plan_design_organization = SponsoredBenefits::Organizations::PlanDesignOrganization.find_by_owner_and_sponsor(broker_agency.id, employer.id)
          return unless plan_design_organization.present?
          plan_design_organization.has_active_broker_relationship = false
          plan_design_organization.sic_code ||= employer.sic_code
          plan_design_organization.expire_proposals
          plan_design_organization.save!
        end
      end

    end
  end
end
