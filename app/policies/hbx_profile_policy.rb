class HbxProfilePolicy < ApplicationPolicy

  def oe_extendable_applications?
    staff_can_extend_open_enrollment?
  end

  def oe_extended_applications?
    staff_can_extend_open_enrollment?
  end

  def edit_open_enrollment?
    staff_can_extend_open_enrollment?
  end

  def extend_open_enrollment?
    staff_can_extend_open_enrollment?
  end

  def close_extended_open_enrollment?
    staff_can_extend_open_enrollment?
  end

  def new_benefit_application?
    staff_can_create_benefit_application?
  end

  def create_benefit_application?
    staff_can_create_benefit_application?
  end

  def edit_fein?
    staff_can_change_fein?
  end

  def update_fein?
    staff_can_change_fein?
  end

  def binder_paid?
    staff_modify_admin_tabs?
  end

  def generate_invoice?
    staff_modify_employer?
  end

  def edit_force_publish?
    staff_can_force_publish?
  end

  def force_publish?
    staff_can_force_publish?
  end

  def employer_invoice?
    index?
  end

  def employer_datatable?
    index?
  end

  def employer_poc?
    index?
  end

  def staff_index?
    index?
  end

  def family_index_dt?
    index?
  end

  def user_account_index?
    staff_can_access_user_account_tab?
  end

  def outstanding_verification_dt?
    index?
  end

  def hide_form?
    staff_can_add_sep?
  end

  def add_sep_form?
    staff_can_add_sep?
  end

  def show_sep_history?
    staff_can_view_sep_history?
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_user_info?
    index?
  end
  # rubocop:enable Naming/AccessorMethodName

  def update_effective_date?
    staff_can_add_sep?
  end

  def calculate_sep_dates?
    staff_can_add_sep?
  end

  def add_new_sep?
    staff_can_add_sep?
  end

  def cancel_enrollment?
    staff_can_cancel_enrollment?
  end

  def update_cancel_enrollment?
    staff_can_cancel_enrollment?
  end

  def terminate_enrollment?
    staff_can_terminate_enrollment?
  end

  def update_terminate_enrollment?
    staff_can_terminate_enrollment?
  end

  def view_enrollment_to_update_end_date?
    staff_can_update_ssn?
  end

  def update_enrollment_terminated_on_date?
    staff_can_update_ssn?
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
    @user.has_role?(:hbx_staff) ||
      @user.has_role?(:csr) ||
      @user.has_role?(:assister)
  end

  def index?
    @user.has_role? :hbx_staff
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

  def general_agency_index?
    index?
  end

  def issuer_index?
    index?
  end

  def verification_index?
    index?
  end

  def binder_index?
    index?
  end

  def binder_index_datatable?
    index?
  end

  def product_index?
    index?
  end

  def assister_index?
    return true if shop_market_primary_family_member?
    return true if shop_market_admin?
    return true if active_associated_shop_market_family_broker?
    return true if active_associated_shop_market_general_agency?

    false
  end

  def request_help?
    return true if shop_market_primary_family_member?

    show?
  end

  def configuration?
    index?
  end

  def view_terminated_hbx_enrollments?
    index?
  end

  def reinstate_enrollment?
    staff_can_reinstate_enrollment?
  end

  def edit_dob_ssn?
    staff_can_update_ssn?
  end

  def verify_dob_change?
    staff_can_update_ssn?
  end

  def update_dob_ssn?
    staff_can_update_ssn?
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

  def aptc_csr_family_index?
    index?
  end

  def update_setting?
    staff_modify_admin_tabs?
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

  private

  def user_hbx_staff_role
    person = user.person
    return nil unless person
    person.hbx_staff_role
  end
end
