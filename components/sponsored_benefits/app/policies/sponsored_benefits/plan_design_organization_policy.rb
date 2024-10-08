# frozen_string_literal: true

module SponsoredBenefits
  # Policy for Broker Agency Plan Design Organization
  class PlanDesignOrganizationPolicy < Policy
    def view_proposals?
      return true if user.has_hbx_staff_role?
      return false unless user.person

      person = user.person

      return true if broker_owns_plan_design_organization_via_broker_agency?(person)

      true if broker_staff_owns_plan_design_organization_via_broker_agency?(person)
    end

    def view_employees?
      view_proposals?
    end

    private

    def broker_staff_owns_plan_design_organization_via_broker_agency?(person)
      broker_agency_staff_roles = person.active_broker_staff_roles
      return false if broker_agency_staff_roles.blank?

      broker_agency_staff_roles.any? do |basr|
        basr.benefit_sponsors_broker_agency_profile_id == record.owner_profile_id
      end
    end

    def broker_owns_plan_design_organization_via_broker_agency?(person)
      return false unless person.broker_role&.active?

      person.broker_role.benefit_sponsors_broker_agency_profile_id == record.owner_profile_id
    end
  end
end
