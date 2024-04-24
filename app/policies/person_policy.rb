# frozen_string_literal: true

# The PersonPolicy class defines the rules for which actions can be performed on a Person object.
# Each public method corresponds to a potential action that can be performed.
# The private methods are helper methods used to determine whether a user has the necessary permissions to perform an action.
class PersonPolicy < ApplicationPolicy
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

  def updateable?
    return true unless role = user.person.hbx_staff_role
    role.permission.modify_family
  end

  def can_download_sbc_documents?
    return true if shop_market_primary_family_member?
    return true if shop_market_admin?
    return true if active_associated_shop_market_family_broker?
    return true if active_associated_shop_market_general_agency?

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
    return true if active_associated_shop_market_family_broker?

    false
  end
end
