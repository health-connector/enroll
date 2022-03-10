# frozen_string_literal: true

class AssignNewParamsForMemberSelection
  include Interactor

  def call
    context.can_shop_shop = context.person.present? && context.person.has_employer_benefits?
    fetch_shopping_role(context.params)
  end

  def fetch_shopping_role(params)
    if params[:employee_role_id].present?
      emp_role_id = params.require(:employee_role_id)
      context.employee_role = context.person.employee_roles.detect { |emp_role| emp_role.id.to_s == emp_role_id.to_s }
    elsif params[:resident_role_id].present?
      context.resident_role = context.person.resident_role
    end
  end
end