class EmployerProfilePolicy < ApplicationPolicy
  def bulk_employee_upload?
    has_modify_permissions?
  end

  def consumer_override?
    has_modify_permissions?
  end

  def delete_documents?
    has_modify_permissions?
  end

  def download_documents?
    has_modify_permissions?
  end

  def download_invoice?
    has_modify_permissions?
  end

  def export_census_employees?
    has_modify_permissions?
  end

  def fire_general_agency?
    return false unless user.person
    return true if user.person.hbx_staff_role

    broker_role = user.person.broker_role
    return false unless broker_role

    assigned_broker = record.broker_agency_accounts.any? { |account| account.writing_agent_id == broker_role.id }
    return true if assigned_broker

    record.general_agency_accounts.any? { |account| account.broker_role_id == broker_role.id }
  end

  def generate_checkbook_urls?
    has_modify_permissions?
  end

  def generate_sic_tree?
    has_modify_permissions?
  end

  def inbox?
    has_modify_permissions?
  end

  def link_from_quote?
    has_modify_permissions?
  end

  def list_enrollments?
    return false unless person=user.person
    return true unless hbx_staff = person.hbx_staff_role

    hbx_staff.permission.list_enrollments
  end

  def match?
    has_modify_permissions?
  end

  def new_document?
    has_modify_permissions?
  end

  def redirect_to_first_allowed?
    has_modify_permissions?
  end

  def revert_application?
    return true unless role = user.person.hbx_staff_role

    role.permission.revert_application
  end

  def update?
    has_modify_permissions?
  end

  def upload_document?
    has_modify_permissions?
  end

  def updateable?
    role = user&.person&.hbx_staff_role
    return true unless role.present?

    role.permission.modify_employer
  end

  def has_modify_permissions?
    return false if user.blank? || user.person.blank?
    return true if  (user.has_hbx_staff_role? && can_modify_employer?) || is_broker_for_employer?(record)

    is_staff_role_for_employer?
  end

  def can_modify_employer?
    user.person.hbx_staff_role.permission.modify_employer
  end

  def is_broker_for_employer?(profile)
    broker_role = user.person.broker_role
    return false unless broker_role

    profile.broker_agency_accounts.any? {|acc| acc.writing_agent_id == broker_role.id}
  end

  def is_staff_role_for_employer?
    active_staff_roles = user.person.employer_staff_roles.active
    active_staff_roles.any? {|role| role.benefit_sponsor_employer_profile_id == record.id }
  end
end
