# frozen_string_literal: true

class BuildMemberGroup
  include Interactor

  def call
    return unless context.hbx_enrollment.present? && context.product.present?

    context.member_group = HbxEnrollmentSponsoredCostCalculator.new(context.hbx_enrollment).groups_for_products([context.product]).first
  end
end