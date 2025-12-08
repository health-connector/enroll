# frozen_string_literal: true

# Policy for controlling access to identity verification processes
# This policy handles Individual Market (IVL) authorization patterns:
# - Self-access: Users can access their own identity verification
# - Family access: IVL family members with consumer roles can access family verification
# - Admin access: HBX staff with family modification permissions can access any verification
class IdentityVerificationPolicy < ApplicationPolicy

  def initialize(user, record)
    super
    @person = record
    @family = record&.primary_family
  end

  # Determines if the user can initiate identity verification for the person
  # Checks IVL-specific access patterns and admin permissions
  def new?
    return false unless @person
    return false unless user&.person

    # User can access their own identity verification
    return true if user.person == @person

    # User can access family member's identity verification if they're primary family member
    return true if ivl_primary_family_member?

    # HBX staff with family modification permissions can access
    return true if hbx_staff_with_family_permissions?

    false
  end

  # Determines if the user can submit identity verification responses
  def create?
    new?
  end

  # Determines if the user can override identity verification (typically admin action)
  # Update is specifically for verification override - more restrictive than normal access
  def update?
    return false unless @person

    # Only HBX staff with appropriate override permissions can do updates
    user_can_override_verification?
  end

  # Determines if the user can view identity verification status/results
  def show?
    new?
  end

  private

  # Check if user is primary member of an IVL family or family member with consumer role
  def ivl_primary_family_member?
    return false unless @family
    return false unless user&.person  # Add nil check for user.person

    primary_person = @family.primary_person
    user_person = user.person

    # User is the primary family member
    return true if primary_person == user_person

    # User is a family member with consumer role (IVL context)
    family_member_ids = @family.family_members.map(&:person_id)
    user_person.id.in?(family_member_ids) && user_person.consumer_role.present?
  end

  # Check if user has HBX staff permissions for family management
  def hbx_staff_with_family_permissions?
    role = user.person&.hbx_staff_role
    return false unless role&.permission

    role.permission.modify_family
  end

  # Check if user has specific permissions to override identity verification
  # This could be expanded in the future for specific verification override roles
  def user_can_override_verification?
    role = user.person&.hbx_staff_role
    return false unless role

    # For now, use existing SSN update permission as proxy for verification override
    # This can be refined with specific verification permissions later
    role.permission.can_update_ssn
  end
end
