# frozen_string_literal: true

#AgentPolicy
class AgentPolicy < ApplicationPolicy
  attr_accessor :person

  def initialize(user, _record)
    super
    @person = user.person
  end

  def home?
    agent?
  end

  def inbox?
    agent?
  end

  def show?
    agent?
  end

  def begin_employee_enrollment?
    agent?
  end

  def begin_consumer_enrollment?
    agent?
  end

  def agent?
    return true if person.csr_role
    return true if person.assister_role
    return true if person.hbx_staff_role
    return true if person.broker_role&.active?

    false
  end
end
