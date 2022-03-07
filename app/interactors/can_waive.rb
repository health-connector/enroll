# frozen_string_literal: true

class CanWaive
  include Interactor

  def call
    return unless context.previous_hbx_enrollment.present? || context.market_kind.present?

    context.waivable = if context.previous_hbx_enrollment.present?
                         context.previous_hbx_enrollment.is_shop?
                       else
                         context.market_kind == "shop"
                       end
  end
end