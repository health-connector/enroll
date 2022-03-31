# frozen_string_literal: true

class FetchShopBenefit
  include Interactor

  def call
    return unless context.market_kind == 'shop' || context.market_kind == 'fehb'

    context.benefit_group = if possible_benefit_package.present? && assigned_benefit_package&.start_on != possible_benefit_package.start_on
                              possible_benefit_package
                            else
                              assigned_benefit_package
                            end
  end

  def assigned_benefit_package
    return unless employee_role.present?

    @assigned_benefit_package ||= employee_role.benefit_package(qle: context.qle, shop_under_current: context.shop_under_current, shop_under_future: context.shop_under_future)
  end

  def possible_benefit_package
    @possible_benefit_package ||= previous_hbx_enrollment.sponsored_benefit_package if context.change_plan.present? && previous_hbx_enrollment.present?
  end

  def previous_hbx_enrollment
    context.previous_hbx_enrollment
  end

  def employee_role
    context.employee_role
  end
end