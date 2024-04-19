# frozen_string_literal: true

class FamilyPolicy < ApplicationPolicy

  def initialize(user, record)
    super
    @family = record
  end

  # Returns the primary person of the family record.
  #
  # @return [Person] The primary person of the family record.
  def primary_person
    record.primary_person
  end

  # Determines if the current user has permission to view the family record.
  # The user can view the record if they are a primary family member,
  # an active associated broker, or an admin in the shop market,
  #
  # @return [Boolean] Returns true if the user has permission to view the record, false otherwise.
  # @note This method checks for permissions across multiple markets and roles.
  def show?
    return true if shop_market_primary_family_member?
    return true if shop_market_admin?
    return true if active_associated_shop_market_family_broker?
    return true if active_associated_shop_market_general_agency?

    false
  end

  def admin_show?
    return true if shop_market_admin?

    false
  end

  def updateable?
    return true unless role = user.person && user.person.hbx_staff_role
    role.permission.modify_family
  end

  def can_update_ssn?
    return false unless role = user.person && user.person.hbx_staff_role
    role.permission.can_update_ssn
  end

  def can_view_username_and_email?
    return false unless role = (user.person && user.person.hbx_staff_role) || (user.person.csr_role)
    role.permission.can_view_username_and_email || user.person.csr_role.present?
  end

  def hbx_super_admin_visible?
    return false unless role = user.person && user.person.hbx_staff_role
    role.permission.can_update_ssn
  end

  def complete_plan_shopping?
    show?
  end

  def create?
    show?
  end

  def edit?
    show?
  end

  def update?
    show?
  end

  def destroy?
    show?
  end

  def index?
    show?
  end

  def new?
    show?
  end

  def home?
    show?
  end

  def manage_family?
    show?
  end

  def personal?
    show?
  end

  def inbox?
    show?
  end

  def verification?
    show?
  end

  def find_sep?
    show?
  end

  def record_sep?
    show?
  end

  def purchase?
    show?
  end

  def check_qle_reason?
    show?
  end

  def check_qle_date?
    show?
  end

  def sep_zip_compare?
    show?
  end

  def brokers?
    show?
  end

  def upload_application?
    admin_show?
  end

  def upload_notice?
    admin_show?
  end

  def upload_notice_form?
    admin_show?
  end

  def transition_family_members?
    admin_show?
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def legacy_show?
    user_person = @user.person
    if user_person
      primary_applicant = @record.primary_applicant
      return true if @record.primary_applicant.person_id == user_person.id
      return true if can_modify_family?(user_person)

      broker_role = user_person.broker_role
      employee_roles = primary_applicant.person.active_employee_roles
      if broker_role
        ivl_broker_account = @record.active_broker_agency_account
        return true if ivl_broker_account && (ivl_broker_account.benefit_sponsors_broker_agency_profile_id == broker_role.benefit_sponsors_broker_agency_profile_id)
        return false unless employee_roles.any?

        broker_agency_profile_account_ids = employee_roles.map do |er|
          er.employer_profile.active_broker_agency_account
        end.compact.map(&:benefit_sponsors_broker_agency_profile_id)
        return true if broker_agency_profile_account_ids.include?(broker_role.benefit_sponsors_broker_agency_profile_id)
      end
      ga_roles = user_person.active_general_agency_staff_roles
      if ga_roles.any? && employee_roles.any?
        general_agency_profile_account_ids = employee_roles.map do |er|
          er.employer_profile.active_general_agency_account
        end.compact.map(&:general_agency_profile_id)
        ga_roles.each do |ga_role|
          return true if general_agency_profile_account_ids.include?(ga_role.general_agency_profile_id)
        end
      end
    end
    false
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def can_modify_family?(user_person)
    hbx_staff_role = user_person.hbx_staff_role
    return false unless hbx_staff_role

    permission = hbx_staff_role.permission
    return false unless permission

    permission.modify_family
  end
end
