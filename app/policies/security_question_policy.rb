# frozen_string_literal: true

# Policy class for security questions.
class SecurityQuestionPolicy < ApplicationPolicy
  # Determines if the user can view the index page of security questions.
  # @return [Boolean] Returns false as this feature is currently turned off.
  def index?
    staff_view_admin_tabs?
  end

  # Determines if the user can view the new security question page.
  # @return [Boolean] Returns false as this feature is currently turned off.
  def new?
    staff_view_admin_tabs?
  end

  # Determines if the user can create a new security question.
  # @return [Boolean] Returns false as this feature is currently turned off.
  def create?
    staff_view_admin_tabs?
  end

  # Determines if the user can view the edit security question page.
  # @return [Boolean] Returns false as this feature is currently turned off.
  def edit?
    staff_view_admin_tabs?
  end

  # Determines if the user can update a security question.
  # @return [Boolean] Returns false as this feature is currently turned off.
  def update?
    index?
  end

  # Determines if the user can destroy a security question.
  # @return [Boolean] Returns false as this feature is currently turned off.
  def destroy?
    staff_view_admin_tabs?
  end
end
