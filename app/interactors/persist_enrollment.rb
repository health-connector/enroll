# frozen_string_literal: true

class PersistEnrollment
  include Interactor

  def call
    hbx_enrollment.update_current(product_id: context.product.id, issuer_profile_id: context.product.issuer_profile_id)

    qle = hbx_enrollment.is_special_enrollment?
    if qle
      sep_id = if hbx_enrollment.is_shop?
                 hbx_enrollment.family.earliest_effective_shop_sep.id
               else
                 hbx_enrollment.family.earliest_effective_ivl_sep.id
               end

      hbx_enrollment.special_enrollment_period_id = sep_id
    end
    hbx_enrollment.aasm_state = 'auto_renewing' if hbx_enrollment.is_active_renewal_purchase?

    hbx_enrollment.select_coverage!(qle: qle) if hbx_enrollment.may_select_coverage?
    hbx_enrollment.update_existing_shop_coverage
  end

  def hbx_enrollment
    context.hbx_enrollment
  end
end