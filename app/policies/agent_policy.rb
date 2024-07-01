# frozen_string_literal: true

#AgentPolicy
class AgentPolicy < ApplicationPolicy
  def home?
    agent_basic_access?
  end

  def inbox?
    agent_basic_access?
  end

  def destroy?
    agent_basic_access?
  end

  def show?
    agent_basic_access?
  end

  def message_show?
    agent?
  end

  def begin_employee_enrollment?
    agent?
  end

  private

  # Checks if the current user has any agent-related role.
  #
  # The user is considered an agent if they have any of the following roles:
  # - CSR
  # - Assister
  # - HBX Staff
  # - Active Broker
  #
  # @return [Boolean] Returns true if the user has an agent-related role, false otherwise.
  # @note This method is used to determine whether the current user is authorized to perform actions related to agent functionalities.
  def agent?
    return false unless account_holder_person
    return true if account_holder_person.csr_role
    return true if account_holder_person.assister_role
    return true if account_holder_person.hbx_staff_role
    return true if account_holder_person.broker_role&.active?

    false
  end

  # Checks if the current user has basic access roles for home and inbox.
  #
  # The user is considered to have basic access if they have any of the following roles:
  # - CSR
  # - Assister
  #
  # @return [Boolean] Returns true if the user has a basic access role, false otherwise.
  # @note This method is used to determine whether the current user is authorized to access home and inbox functionalities.
  def agent_basic_access?
    return false unless account_holder_person
    return true if account_holder_person.csr_role
    return true if account_holder_person.assister_role

    false
  end
end