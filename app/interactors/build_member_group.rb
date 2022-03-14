# frozen_string_literal: true

class BuildMemberGroup
  include Interactor

  def call
    context.member_group = HbxEnrollmentSponsoredCostCalculator.new(context.hbx_enrollment).groups_for_products([context.product]).first
  end
end