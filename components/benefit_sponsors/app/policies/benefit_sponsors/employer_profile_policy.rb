module BenefitSponsors
  class EmployerProfilePolicy < ::ApplicationPolicy

    def show?
      return false unless user.present?
      return true if shop_market_admin? || is_broker_for_employer?(record) || is_general_agency_staff_for_employer?(record)

      is_staff_role_for_employer?
    end

    def show_invoice?
      show?
    end

    def download_invoice?
      show?
    end

    def estimate_cost?
      show?
    end

    def bulk_employee_upload?
      show?
    end

    def can_download_document?
      updateable?
    end

    def show_pending?
      return false unless user.present?
      true
    end

    def coverage_reports?
      return false unless user.present?
      return true if (user.has_hbx_staff_role? && can_list_enrollments?) || is_broker_for_employer?(record) || is_general_agency_staff_for_employer?(record)
      is_staff_role_for_employer?
    end

    def export_census_employees?
      show?
    end

    def inbox?
      show?
    end

    def employer_attestation_create?
      show?
    end

    def employer_attestation_edit?
      shop_market_admin?
    end

    def employer_attestation_update?
      shop_market_admin?
    end

    def authorized_download?
      shop_market_admin?
    end

    def delete_attestation_documents?
      show?
    end

    def verify_attestation?
      shop_market_admin?
    end

    def new?
      show?
    end

    def edit?
      show?
    end

    def update?
      show?
    end

    def cobra?
      show?
    end

    def confirm_effective_date?
      show?
    end

    def cobra_reinstate?
      show?
    end

    def delink?
      show?
    end

    def benefit_group?
      show?
    end

    def change_expected_selection?
      show?
    end

    def rehire?
      show?
    end

    def is_staff_role_for_employer?
      active_staff_roles = user.person.employer_staff_roles.active
      active_staff_roles.any? {|role| role.benefit_sponsor_employer_profile_id == record.id }
    end

    def is_broker_for_employer?(profile)
      broker_role = user.person.broker_role
      return false unless broker_role
      profile.broker_agency_accounts.any? {|acc| acc.writing_agent_id == broker_role.id}
    end

    def is_general_agency_staff_for_employer?(profile)
      # TODO
      false
    end

    def updateable?
      return false if (user.blank? || user.person.blank?)
      return true if  (user.has_hbx_staff_role? && can_modify_employer?) || is_broker_for_employer?(record) || is_general_agency_staff_for_employer?(record)
      is_staff_role_for_employer?
    end

    def list_enrollments?
      coverage_reports?
    end

    def can_list_enrollments?
      user.person.hbx_staff_role.permission.list_enrollments
    end

    def can_modify_employer?
      user.person.hbx_staff_role.permission.modify_employer
    end

    def run_eligibility_check?
      return false unless user.present?

      user.has_hbx_staff_role?
    end

    def can_read_inbox?
      return false if user.blank? || user.person.blank?
      return true if user.has_hbx_staff_role? || is_broker_for_employer?(record) || is_general_agency_staff_for_employer?(record)
      return true if is_staff_role_for_employer?

      false
    end

    def index?
      return false unless account_holder_person
      return true if shop_market_admin?
      return true if is_staff_role_for_employer?
      return true if is_broker_for_employer?(record)
      return true if is_general_agency_staff_for_employer?(record)

      false
    end

    def create?
      index?
    end

    def terminate?
      index?
    end

    def active_broker?
      index?
    end

    def new_document?
      index?
    end

    def employer_attestation_document_download?
      return false unless account_holder_person
      return true if shop_market_admin?
      return true if is_staff_role_for_employer?
      return true if is_broker_for_employer?(record)
      return true if is_general_agency_staff_for_employer?(record)

      false
    end
  end
end
