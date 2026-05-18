# frozen_string_literal: true

class AnnouncementPolicy < ApplicationPolicy
  def index?
    hbx_staff?
  end

  def create?
    modify_admin_tabs?
  end

  def destroy?
    modify_admin_tabs?
  end

  def dismiss?
    return false unless account_holder_person

    has_dismissal_permission?
  end

  private

  # Checks if the current user has HBX staff role
  #
  # @return [Boolean] Returns true if the user has HBX staff role, false otherwise
  def hbx_staff?
    return false unless account_holder_person

    account_holder_person.hbx_staff_role.present?
  end

  # Checks if the current user has permission to modify admin tabs
  #
  # @return [Boolean] Returns true if the user can modify admin tabs, false otherwise
  def modify_admin_tabs?
    return false unless hbx_staff?

    hbx_staff_role = account_holder_person.hbx_staff_role
    return false unless hbx_staff_role&.permission

    hbx_staff_role.permission.modify_admin_tabs
  end

  # Checks if the current user has permission to dismiss announcements
  #
  # @return [Boolean] Returns true if the user can dismiss announcements, false otherwise
  def has_dismissal_permission?
    has_staff_roles? || has_broker_roles? || has_employer_roles?
  end

  # Checks if the current user has staff-related roles
  #
  # @return [Boolean] Returns true if the user has CSR, Assister, or HBX Staff roles
  def has_staff_roles?
    account_holder_person.csr_role.present? ||
      account_holder_person.assister_role.present? ||
      account_holder_person.hbx_staff_role.present?
  end

  # Checks if the current user has broker-related roles
  #
  # @return [Boolean] Returns true if the user has active broker or broker agency staff roles
  def has_broker_roles?
    account_holder_person.broker_role&.active? ||
      account_holder_person.broker_agency_staff_roles&.active&.present?
  end

  # Checks if the current user has employer-related roles
  #
  # @return [Boolean] Returns true if the user has employer staff or employee roles
  def has_employer_roles?
    account_holder_person.has_active_employer_staff_role? ||
      account_holder_person.employee_roles&.present?
  end
end
