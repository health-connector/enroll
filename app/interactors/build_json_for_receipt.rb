# frozen_string_literal: true

class BuildJsonForReceipt
  include Interactor

  def call
    context.json = {enrollment_id: context.hbx_enrollment.id,
                    product_id: context.product.id,
                    coverage_kind: context.coverage_kind,
                    qle: context.qle,
                    employee_is_shopping_before_hire: context.employee_is_shopping_before_hire,
                    can_select_coverage: context.hbx_enrollment.can_select_coverage?(qle: context.qle),
                    event: context.event}
  end
end