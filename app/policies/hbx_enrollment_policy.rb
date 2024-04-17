# frozen_string_literal: true

# pundit Policies to access HbxEnrollment
class HbxEnrollmentPolicy < ApplicationPolicy
  def initialize(user, record)
    super
    @family ||= record.family
  end

  def checkout?
    create?
  end

  def receipt?
    create?
  end

  def thankyou?
    create?
  end

  def waive?
    create?
  end

  def print_waiver?
    create?
  end

  def terminate?
    create?
  end

  def show?
    create?
  end

  def set_elected_aptc?
    create?
  end

  def plans?
    create?
  end

  private

  # # Returns the family associated with the current enrollment.
  # #
  # # @return [Family] The family associated with the current enrollment.
  # def enrollment_family
  #   @enrollment_family ||= record.family
  # end

  # rubocop:disable Metrics/CyclomaticComplexity
  def create?
    return true if shop_market_primary_family_member?
    return true if shop_market_admin?
    return true if active_associated_shop_market_family_broker?
    return true if active_associated_shop_market_general_agency?

    false
  end
  # rubocop:enable Metrics/CyclomaticComplexity
end
