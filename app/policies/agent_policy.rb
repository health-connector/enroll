# frozen_string_literal: true

#AgentPolicy
class AgentPolicy < ApplicationPolicy
  attr_accessor :person

  def initialize(user, _record)
    super
    @person = user.person
  end

  def show?
    return true if person.csr_role
    return true if person.assister_role

    false
  end

  def destroy?
    show?
  end
end
