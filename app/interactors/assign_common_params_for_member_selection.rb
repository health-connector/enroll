# frozen_string_literal: true

class AssignCommonParamsForMemberSelection
  include Interactor

  def call
    context.change_plan = context.params[:change_plan].present? ? context.params[:change_plan] : ''
    context.shop_under_current = context.params[:shop_under_current] == "true"
    context.shop_under_future = context.params[:shop_under_future] == "true"
    context.coverage_kind = context.params[:coverage_kind].present? ? context.params[:coverage_kind] : 'health'
    context.enrollment_kind = context.params[:enrollment_kind].present? ? context.params[:enrollment_kind] : ''
    context.shop_for_plans = context.params[:shop_for_plans].present? ? context.params[:shop_for_plans] : ''
    context.optional_effective_on = context.params[:effective_on_option_selected].present? ? Date.strptime(context.params[:effective_on_option_selected], '%m/%d/%Y') : nil
    context.qle = (context.change_plan == 'change_by_qle' || context.enrollment_kind == 'sep')
  end
end
