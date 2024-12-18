class HbxProfilePolicy < ApplicationPolicy

  def binder_paid?
    staff_modify_admin_tabs?
  end

  def transmit_group_xml?
    staff_modify_admin_tabs?
  end

  def update_cancel_enrollment?
    can_update_ssn?
  end

  def update_terminate_enrollment?
    can_update_ssn?
  end

  # Determines if the current user has permission to access the assister index.
  # The user can access the assister index if they are a primary family member,
  # an admin, an active associated broker staff, or an active associated broker in the ACA Shop market.
  #
  # @return [Boolean] Returns true if the user has permission to access the assister index, false otherwise.
  # @note This method checks for permissions across multiple roles.
  def assister_index?
    # Fall back on a family if it exists for the current user.
    @family = account_holder_family

    return true if shop_market_primary_family_member?
    return true if shop_market_admin?
    return true if active_associated_shop_market_family_broker?
    return true if active_associated_shop_market_general_agency?

    false
  end

  def can_update_ssn?
    role = user_hbx_staff_role
    return false unless role

    role.permission.can_update_ssn
  end

  def view_admin_tabs?
    role = user_hbx_staff_role
    return false unless role
    role.permission.view_admin_tabs
  end

  def modify_admin_tabs?
    role = user_hbx_staff_role
    return false unless role
    role.permission.modify_admin_tabs
  end

  def view_the_configuration_tab?
    role = user_hbx_staff_role
    return false unless role
    role.permission.view_the_configuration_tab
  end

  def can_submit_time_travel_request?
    role = user_hbx_staff_role
    return false unless role
    return false unless role.permission.name == "super_admin"
    role.permission.can_submit_time_travel_request
  end

  def can_view_or_change_translations?
    user_hbx_staff_role&.permission&.name == "super_admin"
  end

  def send_broker_agency_message?
    role = user_hbx_staff_role
    return false unless role
    role.permission.send_broker_agency_message
  end

  def approve_broker?
    role = user_hbx_staff_role
    return false unless role
    role.permission.approve_broker
  end

  def approve_ga?
    role = user_hbx_staff_role
    return false unless role
    role.permission.approve_ga
  end

  def can_extend_open_enrollment?
    role = user_hbx_staff_role
    return false unless role
    role.permission.can_extend_open_enrollment
  end

  def can_modify_plan_year?
    return true unless role = user.person.hbx_staff_role
    role.permission.can_modify_plan_year
  end

  def can_create_benefit_application?
    role = user_hbx_staff_role
    return false unless role
    role.permission.can_create_benefit_application?
  end

  def can_change_fein?
    role = user_hbx_staff_role
    return false unless role
    role.permission.can_change_fein
  end

  def can_force_publish?
    role = user_hbx_staff_role
    return false unless role
    role.permission.can_force_publish
  end

  def show?
    index? ||
      @user.has_role?(:csr) ||
      @user.has_role?(:assister)
  end

  def index?
    return true if shop_market_admin?

    false
  end

  def employer_index?
    index?
  end

  def family_index?
    index?
  end

  def broker_agency_index?
    index?
  end

  def issuer_index?
    index?
  end

  def product_index?
    index?
  end

  def configuration?
    view_the_configuration_tab?
  end

  def new?
    @user.has_role? :hbx_staff
  end

  def edit?
    if @user.has_role?(:hbx_staff)
      @record.id == @user.try(:person).try(:hbx_staff_role).try(:hbx_profile).try(:id)
    else
      false
    end
  end

  def inbox?
    index?
  end

  def create?
    new?
  end

  def update?
    edit?
  end

  def destroy?
    edit?
  end

  def set_date?
    index?
  end

  def can_add_sep?
    role = user_hbx_staff_role
    return false unless role
    role.permission.can_add_sep
  end

  def can_access_user_account_tab?
    hbx_staff_role = @user.person && @user.person.hbx_staff_role
    return hbx_staff_role.permission.can_access_user_account_tab if hbx_staff_role
    return false
  end

  def can_update_enrollment_end_date?
    role = user_hbx_staff_role
    return false unless role
    role.permission.can_update_enrollment_end_date
  end

  def can_reinstate_enrollment?
    role = user_hbx_staff_role
    return false unless role
    role.permission.can_reinstate_enrollment
  end

  def confirm_lock?
    staff_can_lock_unlock?
  end

  def lockable?
    staff_can_lock_unlock?
  end

  def reset_password?
    staff_can_reset_password?
  end

  def confirm_reset_password?
    staff_can_reset_password?
  end

  def change_username_and_email?
    staff_can_change_username_and_email?
  end

  def confirm_change_username_and_email?
    staff_can_change_username_and_email?
  end

  def login_history?
    staff_view_login_history?
  end

  def can_mark_pvp_eligibilities?
    user_hbx_staff_role&.permission&.can_update_pvp_eligibilities?
  end

  private

  def user_hbx_staff_role
    person = user.person
    return nil unless person
    person.hbx_staff_role
  end
end
