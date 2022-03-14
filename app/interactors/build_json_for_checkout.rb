# frozen_string_literal: true

class BuildJsonForCheckout
  include Interactor

  def call
    context.json = {product: context.product,
                    enrollment: context.hbx_enrollment,
                    member_group: context.member_group,
                    employer_profile: context.employer_profile,
                    coverage_kind: context.coverage_kind,
                    enrollment_kind: context.enrollment_kind,
                    market_kind: context.market_kind,
                    family: context.family,
                    use_family_deductable: context.use_family_deductable,
                    enrollable: context.enrollable,
                    waivable: context.waivable}
  end
end