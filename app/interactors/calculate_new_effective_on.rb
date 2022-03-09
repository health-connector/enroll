# frozen_string_literal: true

class CalculateNewEffectiveOn
  include Interactor

  before do
    context.fail!(message: "missing market_kind") unless context.market_kind.present?
  end

  def call
    context.new_effective_on = if context.market_kind == "individual"
                                 calculate_effective_on
                               else
                                 calculate_effective_on(context.employee_role, context.benefit_group)

                                 # Set new_effective_on to the date choice selected by user if this is a QLE with date options available.
                                 # Date.strptime(context.params[:effective_on_option_selected], '%m/%d/%Y') if context.params[:effective_on_option_selected].present?
                                 #
                                 # context.previous_hbx_enrollment.effective_on if context.change_plan == 'change_plan' && context.previous_hbx_enrollment.present?
                               end
  end

  def calculate_effective_on(employee_role = nil, benefit_group = nil)
    HbxEnrollment.calculate_effective_on_from(market_kind: context.market_kind,
                                              qle: (context.change_plan == 'change_by_qle' or context.enrollment_kind == 'sep'),
                                              family: context.primary_family,
                                              employee_role: employee_role,
                                              benefit_group: benefit_group)
  end
end