# frozen_string_literal: true

class AssignParamsToContext
  include Interactor

  def call
    context.change_plan = context.params[:change_plan].present? ? context.params[:change_plan] : ''
    context.shop_under_current = context.params[:shop_under_current] == "true"
    context.shop_under_future = context.params[:shop_under_future] == "true"
    context.coverage_kind = context.params[:coverage_kind].present? ? context.params[:coverage_kind] : 'health'
    context.enrollment_kind = context.params[:enrollment_kind].present? ? context.params[:enrollment_kind] : ''
    context.shop_for_plans = context.params[:shop_for_plans].present? ? context.params[:shop_for_plans] : ''
    context.optional_effective_on = context.params[:effective_on_option_selected].present? ? Date.strptime(context.params[:effective_on_option_selected], '%m/%d/%Y') : nil
    fetch_shopping_role(context.params)
    context.qle = (context.change_plan == 'change_by_qle' || context.enrollment_kind == 'sep')
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