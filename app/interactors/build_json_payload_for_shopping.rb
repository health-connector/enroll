# frozen_string_literal: true

class BuildJsonPayloadForShopping
  include Interactor

  before do
    context.fail!(message: "In order to continue, at least one member must be selected to enroll in coverage.") unless context[:shopping_enrollments].first&.sponsored_benefit_package.present?
  end

  def call
    # TODO: change_plan attribute is set when shopping for new plan when there is an existing plan.
    # in countinuous shopping this is values is setting for both coverages
    context.plan_selection_json = context.shopping_enrollments.each_with_object({}) do |enrollment, output|
      output[enrollment.coverage_kind.to_sym] = {enrollment_id: enrollment.id,
                                                 market_kind: enrollment.kind,
                                                 enrollment_kind: context.enrollment_kind,
                                                 change_plan: context.change_plan,
                                                 selected_to_waive: selected_to_waive(enrollment),
                                                 waiver_reason: get_waiver_reason(enrollment) }
    end

    context.plan_selection_json[:health_offering] = offering_health
    context.plan_selection_json[:dental_offering] = offering_dental
    context.plan_selection_json[:cart] = context.params[:cart]
    context.plan_selection_json[:event] = context.params[:event]
  end

  def selected_to_waive(enrollment)
    context.enrollments_to_waive.include?(enrollment.coverage_kind)
  end

  def get_waiver_reason(enrollment)
    context.params[:waiver_reason] if enrollment.coverage_kind == 'health'
  end

  def offering_health
    return unless context[:shopping_enrollments].present?

    context[:shopping_enrollments].first.sponsored_benefit_package.health_sponsored_benefit.present?
  end

  def offering_dental
    return unless context[:shopping_enrollments].present?

    context[:shopping_enrollments].first.sponsored_benefit_package.dental_sponsored_benefit.present?
  end
end