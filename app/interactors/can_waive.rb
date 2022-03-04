# frozen_string_literal: true

class CanWaive
  include Interactor

  before do
    return unless context.previous_hbx_enrollment.present? || context.market_kind.present?
  end

  def call
    context.waivable = context.previous_hbx_enrollment.is_shop? || context.market_kind == "shop"
  end
end