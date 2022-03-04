# frozen_string_literal: true

class FetchShopBenefit
  include Interactor

  before do
    return unless context.market_kind == 'shop' || context.market_kind == 'fehb'
  end

  def call
    assigned_benefit_package = context.employee_role.benefit_package(qle: context.qle, shop_under_current: context.shop_under_current, shop_under_future: context.shop_under_future) if context.employee_role.present?

    possible_benefit_package = context.previous_hbx_enrollment.sponsored_benefit_package if context.change_plan.present? && context.previous_hbx_enrollment.present?

    context.benefit_group = assigned_benefit_package&.start_on != possible_benefit_package.start_on ? possible_benefit_package : assigned_benefit_package
  end
end