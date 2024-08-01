# frozen_string_literal: true

# The PersonPolicy class defines the rules for which actions can be performed on a Person object.
# Each public method corresponds to a potential action that can be performed.
# The private methods are helper methods used to determine whether a user has the necessary permissions to perform an action.
class PersonPolicy < ApplicationPolicy
  ACCESSABLE_ROLES = %w[hbx_staff_role broker_role active_broker_staff_roles].freeze

  def initialize(user, record)
    super
    @family = record.primary_family if record.is_a?(Person)
  end

  def can_download_document?
    allowed_to_download?
  end

  def can_delete_document?
    allowed_to_download?
  end

  def can_update?
    allowed_to_modify?
  end

  def updateable?
    return true unless role = user.person.hbx_staff_role

    role.permission.modify_family
  end

  def can_read_inbox?
    person = user&.person
    return false unless person
    return true if person.hbx_staff_role
    return true if person.broker_role || record&.broker_role

    false
  end

  private

  def allowed_to_download?
    allowed_to_access?
  end

  # The user can download the document if they are a primary family member
  #
  # @return [Boolean] Returns true if the user has permission to download the document, false otherwise.
  def allowed_to_access?
    return true if shop_market_primary_family_member?
    return true if shop_market_admin?
    return true if family.present? && active_associated_shop_market_family_broker?
    return true if active_associated_shop_market_person_broker?

    false
  end

  def allowed_to_modify?
    (current_user.person == record) || (current_user == associated_user) || role_has_permission_to_modify?
  end

  def associated_user
    associated_family&.primary_person&.user
  end

  def current_user
    user
  end

  def associated_family
    record.primary_family
  end

  def role_has_permission_to_modify?
    role.present? && (can_hbx_staff_modify? || can_broker_modify?)
  end

  def can_hbx_staff_modify?
    role.is_a?(HbxStaffRole) && role&.permission&.modify_family
  end

  def can_broker_modify?
    (role.is_a?(::BrokerRole) || role.is_a?(::BrokerAgencyStaffRole)) && broker_agency_profile_matches?
  end

  def broker_agency_profile_matches?
    agency_id = role&.benefit_sponsors_broker_agency_profile_id

    family_active_broker = associated_family&.active_broker_agency_account
    active_er = associated_family.primary_person&.active_employee_roles&.first
    employer_active_broker = active_er&.employer_profile&.active_broker_agency_account

    broker_matches?(family_active_broker, agency_id) || broker_matches?(employer_active_broker, agency_id)
  end

  def broker_matches?(broker, agency_id)
    broker.present? && broker.benefit_sponsors_broker_agency_profile_id == agency_id
  end

  def role
    @role ||= find_role
  end

  def find_role
    person = user&.person
    return nil unless person

    ACCESSABLE_ROLES.detect do |role|
      return person.send(role) if person.respond_to?(role) && person.send(role)
    end

    nil
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def active_associated_shop_market_person_broker?
    broker = account_holder_person&.broker_role
    broker_staff_roles = account_holder_person&.broker_agency_staff_roles&.active
    broker_agency_profile_id = record&.broker_role&.benefit_sponsors_broker_agency_profile_id

    return false if broker.blank? && broker_staff_roles.blank?
    return false unless broker&.active?
    return true if broker.present? && (broker.benefit_sponsors_broker_agency_profile_id == broker_agency_profile_id)
    return true if broker_staff_roles.present? && broker_staff_roles.pluck(:benefit_sponsors_broker_agency_profile_id).include?(broker_agency_profile_id)

    false
  end
  # rubocop:enable Metrics/CyclomaticComplexity

end
