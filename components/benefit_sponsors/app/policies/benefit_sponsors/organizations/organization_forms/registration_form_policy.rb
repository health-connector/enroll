# frozen_string_literal: true

module BenefitSponsors
  module Organizations
    module OrganizationForms
      class RegistrationFormPolicy < ApplicationPolicy

        attr_reader :service

        def initialize(user, record)
          super
          @service = BenefitSponsors::Services::NewProfileRegistrationService.new(
            profile_id: record.organization.profile.id,
            profile_type: record.profile_type
          )
        end

        def new?
          return false if benefit_sponsor_not_logged_in?

          true
        end

        def create?
          return false if benefit_sponsor_not_logged_in?
          return true unless (role = user&.person && user.person.hbx_staff_role)

          role.permission.modify_employer
        end

        def edit?
          return false unless user&.person
          return true if admin?
          return true if can_edit?

          false
        end

        def update?
          return true if can_update?
          return true unless (role = user&.person && user.person.hbx_staff_role)
          return role.permission.modify_employer if is_employer_profile?

          role.permission.modify_admin_tabs
        end

        def admin?
          user.has_hbx_staff_role?
        end

        def can_edit?
          return true if is_employer_profile? && service.is_broker_for_employer?(user, record)

          service.is_staff_for_agency?(user, record)
        end

        def can_update?
          can_edit?
        end

        def is_broker_profile?
          profile_type == "broker_agency"
        end

        def is_employer_profile?
          profile_type == "benefit_sponsor"
        end

        def profile_type
          service.profile_type
        end

        def benefit_sponsor_not_logged_in?
          return false unless is_employer_profile?

          user.blank?
        end

        def broker_agency_registered?
          user.present? && (user.has_broker_agency_staff_role? || user.has_broker_role?)
        end

        def redirect_home?
          return false if record.portal && user.blank?
          return service.is_benefit_sponsor_already_registered?(user, record) if is_employer_profile?

          return service.is_broker_agency_registered?(user, record) if is_broker_profile?

          true
        end
      end
    end
  end
end
