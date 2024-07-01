# frozen_string_literal: true

class FetchShoppingRole
  include Interactor

  before do
    context.fail!(message: "missing person") unless context.person.present?
  end

  def call
    context.role = possible_role
  end

  def possible_role
    if context.employee_role.present?
      context.employee_role
    elsif context.employee_role.nil? && context.person.has_active_employee_role?
      context.employee_role = context.person&.active_employee_roles&.last
    elsif context.person.consumer_role.present?
      context.consumer_role = context.person&.consumer_role
    elsif context.resident_role.present?
      context.resident_role
    end
  end
end
