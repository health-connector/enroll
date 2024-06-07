class EmployerProfilePolicy < ApplicationPolicy
  def bulk_employee_upload?
    updateable?
  end

  def consumer_override?
    updateable?
  end

  def delete_documents?
    updateable?
  end

  def download_documents?
    updateable?
  end

  def download_invoice?
    updateable?
  end

  def export_census_employees?
    updateable?
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
    updateable?
  end

  def generate_sic_tree?
    updateable?
  end

  def inbox?
    updateable?
  end

  def link_from_quote?
    updateable?
  end

  def list_enrollments?
    return false unless person=user.person
    return true unless hbx_staff = person.hbx_staff_role

    hbx_staff.permission.list_enrollments
  end

  def match?
    updateable?
  end

  def new_document?
    updateable?
  end

  def redirect_to_first_allowed?
    updateable?
  end

  def revert_application?
    return true unless role = user.person.hbx_staff_role

    role.permission.revert_application
  end

  def update?
    updateable?
  end

  def upload_document?
    updateable?
  end

  def updateable?
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
