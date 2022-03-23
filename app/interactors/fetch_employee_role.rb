# frozen_string_literal: true

class FetchEmployeeRole
  include Interactor

  before do
    context.fail!(message: "missing employee_role_id  in params") unless employee_role_id.present?
  end

  def call
    employee_role = context.person.active_employee_roles.select{|ee| ee.id.to_s == employee_role_id}.first
    if employee_role
      context.employee_role = employee_role
      context.census_employee = employee_role.census_employee
    else
      context.fail!(message: "no employee_role found for given id")
    end
  rescue StandardError => _e
    context.fail!(message: "invalid employee role ID")
  end

  def employee_role_id
    context.params[:employee_role_id]
  end
end