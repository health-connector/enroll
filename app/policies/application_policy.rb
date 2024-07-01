# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record, :family

  def initialize(user, record)
    @user = user
    @record = record
  end

  # Returns the user who is the account holder.
  #
  # @return [User] The user who is the account holder.
  def account_holder
    user
  end

  # Returns the person who is the account holder.
  # The method uses memoization to store the result of the first call to it and then return that result on subsequent calls,
  # instead of calling `account_holder.person` each time.
  #
  # @return [Person] The person who is the account holder.
  def account_holder_person
    return @account_holder_person if defined? @account_holder_person

    @account_holder_person = account_holder&.person
  end

  # Returns the family of the account holder.
  # If the @account_holder_family is defined and is set to nil, then the method will return nil.
  # Otherwise, it will fetch the value of `account_holder_person&.primary_family` and returns the @account_holder_family.
  # If we use `@account_holder_family ||= account_holder_person&.primary_family` when the value is nil, the code will call `account_holder_person.primary_family` which is not necessary.
  # Reference: https://www.justinweiss.com/articles/4-simple-memoization-patterns-in-ruby-and-one-gem/
  #
  # @return [Family, nil] The family of the account holder or nil if not defined or not present.
  def account_holder_family
    return @account_holder_family if defined? @account_holder_family

    @account_holder_family = account_holder_person&.primary_family
  end

  # @!group ACA Shop Market related methods

  # Checks if the account holder is a primary family member in the ACA Shop market for the given family.
  # A user is considered a primary family member in the ACA Shop market if they have an employee role and they are the primary person of the given family.
  #
  # @param family [Family] The family to check.
  # @return [Boolean] Returns true if the account holder is a primary family member in the ACA Shop market for the given family, false otherwise.
  def shop_market_primary_family_member?
    primary_person = family&.primary_person
    return false unless primary_person

    primary_person.employee_roles.present? && account_holder_person == primary_person
  end

  # Checks if the account holder is an admin in the shop market.
  # A user is considered an admin in the shop market if they have an hbx staff role and they have the permission to modify a family.
  # TODO: We need to check if Primary Person's RIDP needs to be verified for Hbx Staff Admins
  #
  # @return [Boolean] Returns true if the account holder is an admin in the shop market, false otherwise.
  def shop_market_admin?
    return false if hbx_role.blank?

    permission = hbx_role.permission
    return false if permission.blank?

    permission.modify_family

    # permission.modify_employer
  end

  def coverall_market_admin?
    shop_market_admin?
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/ParameterLists

  def active_associated_shop_market_family_broker?
    broker = account_holder_person&.broker_role
    broker_staff_roles = account_holder_person&.broker_agency_staff_roles&.active

    return false if broker.blank? && broker_staff_roles.blank?
    return false if broker.present? && (!broker.active? || !broker.shop_market?)
    return true if broker.present? && shop_market_family_broker_agency_ids.include?(broker.benefit_sponsors_broker_agency_profile_id)
    return true if broker_staff_roles.present? && (broker_staff_roles.pluck(:benefit_sponsors_broker_agency_profile_id) & shop_market_family_broker_agency_ids).present?

    false
  end

  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/ParameterLists

  def active_associated_shop_market_general_agency?
    account_holder_ga_roles = account_holder_person&.active_general_agency_staff_roles
    return false if account_holder_ga_roles.blank?
    return false if broker_profile_ids.blank?

    ::SponsoredBenefits::Organizations::PlanDesignOrganization.where(
      :owner_profile_id.in => broker_profile_ids,
      :general_agency_accounts => {
        :"$elemMatch" => {
          aasm_state: :active,
          :benefit_sponsrship_general_agency_profile_id.in => account_holder_ga_roles.map(&:benefit_sponsors_general_agency_profile_id)
        }
      }
    ).present?
  end

  # @endgrop

  # @!group Hbx Staff Role permissions

  def staff_view_admin_tabs?
    permission&.view_admin_tabs
  end

  def staff_modify_employer?
    permission&.modify_employer
  end

  def staff_modify_admin_tabs?
    permission&.modify_admin_tabs
  end

  def staff_view_the_configuration_tab?
    permission&.view_the_configuration_tab
  end

  def staff_can_submit_time_travel_request?
    permission&.can_submit_time_travel_request
  end

  def staff_can_edit_aptc?
    permission&.can_edit_aptc
  end

  def staff_send_broker_agency_message?
    permission&.send_broker_agency_message
  end

  def staff_approve_broker?
    permission&.approve_broker
  end

  def staff_approve_ga?
    permission&.approve_ga
  end

  def staff_can_extend_open_enrollment?
    permission&.can_extend_open_enrollment
  end

  def staff_can_modify_plan_year?
    permission&.can_modify_plan_year
  end

  def staff_can_create_benefit_application?
    permission&.can_create_benefit_application
  end

  def staff_can_change_fein?
    permission&.can_change_fein
  end

  def staff_can_force_publish?
    permission&.can_force_publish
  end

  def staff_can_access_age_off_excluded?
    permission&.can_access_age_off_excluded
  end

  def staff_can_send_secure_message?
    permission&.can_send_secure_message
  end

  def staff_can_add_sep?
    permission&.can_add_sep
  end

  def staff_can_view_sep_history?
    permission&.can_view_sep_history
  end

  def staff_can_cancel_enrollment?
    permission&.can_cancel_enrollment
  end

  def staff_can_terminate_enrollment?
    permission&.can_terminate_enrollment
  end

  def staff_can_reinstate_enrollment?
    permission&.can_reinstate_enrollment
  end

  def staff_can_access_accept_reject_paper_application_documents?
    permission&.can_access_accept_reject_paper_application_documents
  end

  def staff_can_access_user_account_tab?
    permission&.can_access_user_account_tab
  end

  def staff_can_update_ssn?
    permission&.can_update_ssn
  end

  def staff_can_lock_unlock?
    permission&.can_lock_unlock
  end

  def staff_can_reset_password?
    permission&.can_reset_password
  end

  def staff_can_change_username_and_email?
    permission&.can_change_username_and_email
  end

  def staff_view_login_history?
    permission&.view_login_history
  end

  def permission
    return @permission if defined? @permission

    @permission = hbx_role&.permission
  end

  def hbx_role
    return @hbx_role if defined? @hbx_role

    @hbx_role = account_holder_person&.hbx_staff_role
  end

  # @!endgroup

  def index?
    read_all?
  end

  def show?
    scope.where(:id => record.id).exists?
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    update_all?
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def scope
    Pundit.policy_scope!(user, record.class)
  end

  def read_all?
    @user.has_role? :employer_staff or
      @user.has_role? :employee or
      @user.has_role? :broker or
      @user.has_role? :broker_agency_staff or
      @user.has_role? :consumer or
      @user.has_role? :resident or
      @user.has_role? :hbx_staff or
      @user.has_role? :system_service or
      @user.has_role? :web_service or
      @user.has_role? :assister or
      @user.has_role? :csr
  end

  def update_all?
    @user.has_role? :broker_agency_staff or
      @user.has_role? :assister or
      @user.has_role? :csr
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope
    end
  end

  private

  def broker_profile_ids
    return @broker_profile_ids if defined? @broker_profile_ids

    @broker_profile_ids = shop_market_family_broker_agency_ids
  end

  def shop_market_family_broker_agency_ids
    return @shop_market_family_broker_agency_ids if defined? @shop_market_family_broker_agency_ids

    @shop_market_family_broker_agency_ids = family.primary_person.active_employee_roles.map do |er|
      er.employer_profile&.active_broker_agency_account&.benefit_sponsors_broker_agency_profile_id
    end.compact
  end
end
