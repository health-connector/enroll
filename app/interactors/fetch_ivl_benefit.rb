# frozen_string_literal: true

class FetchIvlBenefit
  include Interactor

  before do
    context.fail!(message: "missing person") unless context.person.present?
  end

  def call
    if context.market_kind == 'individual' || context.person.has_active_consumer_role?
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

    correct_effective_on = CalculateNewEffectiveOn.call
    ivl_benefit = HbxProfile.current_hbx.benefit_sponsorship.benefit_coverage_periods.select{|bcp| bcp.contains?(correct_effective_on)}.first.benefit_packages.select{|bp|  bp[:title] == "individual_health_benefits_#{correct_effective_on.year}"}.first

    context.benefit = ivl_benefit
  end
end