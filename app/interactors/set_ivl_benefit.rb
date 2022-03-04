# frozen_string_literal: true

class SetIvlBenefit
  include Interactor

  before do
    context.fail!(message: "missing person") unless context.person.present?
  end

  def call
    if context.market_kind == 'individual'
      assign_ivl_benefit
    elsif context.person.has_active_consumer_role?
      assign_ivl_benefit
    elsif context.person.resident_role?
      true
    end
  end

  def assign_ivl_benefit
    if context.params[:hbx_enrollment_id].present?
      session[:pre_hbx_enrollment_id] = context.params[:hbx_enrollment_id]
      previous_hbx = context.previous_hbx_enrollment
      previous_hbx.update_current(changing: true) if previous_hbx.present?
    end

    correct_effective_on = calculate_effective_on(context.market_kind, nil, nil)
    ivl_benefit = HbxProfile.current_hbx.benefit_sponsorship.benefit_coverage_periods.select{|bcp| bcp.contains?(correct_effective_on)}.first.benefit_packages.select{|bp|  bp[:title] == "individual_health_benefits_#{correct_effective_on.year}"}.first

    context.benefit = ivl_benefit
  end

  def calculate_effective_on(market_kind, employee_role, benefit_group)
    HbxEnrollment.calculate_effective_on_from(market_kind: market_kind,
                                              qle: (context.change_plan == 'change_by_qle' or context.enrollment_kind == 'sep'),
                                              family: context.family,
                                              employee_role: employee_role,
                                              benefit_group: benefit_group,
                                              benefit_sponsorship: HbxProfile.current_hbx&.benefit_sponsorship)
  end
end