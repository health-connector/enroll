# frozen_string_literal: true

class AssignChangePlanForShop
  include Interactor

  def call
    return unless context.previous_hbx_enrollment&.is_shop? && context.primary_family&.latest_shop_sep.present?

    benefit_package = context.previous_hbx_enrollment.sponsored_benefit_package
    context.change_plan = 'change_by_qle' if benefit_package&.effective_period&.cover?(context.primary_family.latest_shop_sep.effective_on)
  end
end